"""Unit tests for scripts/archive_queue.py.

Run with:
    .venv/bin/python -m pytest tests/test_archive_queue.py -v

All tests use a temporary ROOT via monkeypatch — the real project tree is never touched.
"""
from __future__ import annotations

import textwrap
from pathlib import Path

import pytest
from ruamel.yaml import YAML

import sys

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import archive_queue as aq  # noqa: E402


@pytest.fixture
def tmp_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Redirect aq.ROOT to a temp dir and build the expected subtree."""
    monkeypatch.setattr(aq, "ROOT", tmp_path)
    (tmp_path / "queue" / "inbox").mkdir(parents=True)
    (tmp_path / "queue" / "tasks").mkdir(parents=True)
    (tmp_path / "queue" / "reports").mkdir(parents=True)
    return tmp_path


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content), encoding="utf-8")


def _load_rt(path: Path):
    y = YAML(typ="rt")
    with path.open("r", encoding="utf-8") as f:
        return y.load(f)


# --- parse_cmd_id / cutoff arithmetic --------------------------------------


def test_parse_cmd_id_basic():
    assert aq.parse_cmd_id("cmd_080") == 80
    assert aq.parse_cmd_id("cmd_001") == 1
    assert aq.parse_cmd_id("cmd_100") == 100
    assert aq.parse_cmd_id(" cmd_042 ") == 42


def test_parse_cmd_id_invalid():
    with pytest.raises(ValueError):
        aq.parse_cmd_id("cmd_abc")
    with pytest.raises(ValueError):
        aq.parse_cmd_id("080")
    with pytest.raises(ValueError):
        aq.parse_cmd_id("")


def test_numeric_compare_not_lexicographic():
    # cmd_100 > cmd_080 (numeric), not < cmd_080 (lexicographic)
    assert aq._eligible("cmd_100", "done", 80) is False
    assert aq._eligible("cmd_079", "done", 80) is True


# --- shogun_to_karo ---------------------------------------------------------


def _sk_yaml(entries: list[tuple[str, str]]) -> str:
    body = []
    for cid, status in entries:
        body.append(
            f"  - id: {cid}\n"
            f"    timestamp: \"2026-01-01T00:00:00+09:00\"\n"
            f"    # comment: important note on {cid}\n"
            f"    command: |\n"
            f"      multiline\n"
            f"      block for {cid}\n"
            f"    status: {status}\n"
        )
    return "commands:\n" + "".join(body)


def test_shogun_filters_done_and_cancelled_below_cutoff(tmp_root: Path):
    p = tmp_root / "queue" / "shogun_to_karo.yaml"
    _write(
        p,
        _sk_yaml(
            [
                ("cmd_001", "done"),
                ("cmd_050", "cancelled"),
                ("cmd_079", "done"),
                ("cmd_080", "done"),
                ("cmd_081", "pending"),
                ("cmd_082", "in_progress"),
                ("cmd_090", "done"),
            ]
        ),
    )
    res = aq.handle_shogun_to_karo(p, cutoff=80, dry_run=False)
    assert res.archived_count == 3  # 001, 050, 079
    assert res.kept_count == 4
    data = _load_rt(p)
    ids = [e["id"] for e in data["commands"]]
    assert ids == ["cmd_080", "cmd_081", "cmd_082", "cmd_090"]


def test_shogun_cutoff_itself_preserved(tmp_root: Path):
    p = tmp_root / "queue" / "shogun_to_karo.yaml"
    _write(p, _sk_yaml([("cmd_080", "done"), ("cmd_079", "done")]))
    aq.handle_shogun_to_karo(p, cutoff=80, dry_run=False)
    ids = [e["id"] for e in _load_rt(p)["commands"]]
    assert "cmd_080" in ids, "cutoff_cmd_id itself must be preserved"
    assert "cmd_079" not in ids


def test_shogun_pending_never_archived_even_if_old(tmp_root: Path):
    p = tmp_root / "queue" / "shogun_to_karo.yaml"
    _write(
        p,
        _sk_yaml(
            [
                ("cmd_001", "pending"),
                ("cmd_002", "in_progress"),
                ("cmd_003", "partial"),
                ("cmd_004", "done"),
            ]
        ),
    )
    aq.handle_shogun_to_karo(p, cutoff=999, dry_run=False)
    ids = [e["id"] for e in _load_rt(p)["commands"]]
    assert ids == ["cmd_001", "cmd_002", "cmd_003"]


def test_shogun_dry_run_non_destructive(tmp_root: Path):
    p = tmp_root / "queue" / "shogun_to_karo.yaml"
    original = _sk_yaml([("cmd_001", "done"), ("cmd_090", "done")])
    _write(p, original)
    res = aq.handle_shogun_to_karo(p, cutoff=80, dry_run=True)
    assert res.archived_count == 1
    assert p.read_text(encoding="utf-8") == textwrap.dedent(original)


def test_shogun_comment_preserved(tmp_root: Path):
    p = tmp_root / "queue" / "shogun_to_karo.yaml"
    _write(p, _sk_yaml([("cmd_001", "done"), ("cmd_090", "done")]))
    aq.handle_shogun_to_karo(p, cutoff=80, dry_run=False)
    content = p.read_text(encoding="utf-8")
    assert "# comment: important note on cmd_090" in content
    assert "multiline" in content


# --- inbox -----------------------------------------------------------------


def test_inbox_read_false_never_archived(tmp_root: Path):
    p = tmp_root / "queue" / "inbox" / "ashigaru2.yaml"
    _write(
        p,
        """\
        messages:
        - content: 'cmd_001 old message'
          from: karo
          id: msg_1
          read: false
          timestamp: '2026-01-01T00:00:00'
          type: task_assigned
        - content: 'cmd_001 read old'
          from: karo
          id: msg_2
          read: true
          timestamp: '2026-01-02T00:00:00'
          type: task_assigned
        """,
    )
    res = aq.handle_inbox(p, cutoff=80, dry_run=False)
    assert res.archived_count == 1
    data = _load_rt(p)
    remaining = [m["id"] for m in data["messages"]]
    assert "msg_1" in remaining  # read:false kept even though old
    assert "msg_2" not in remaining


def test_inbox_max_cmd_rule_conservative(tmp_root: Path):
    # Message mentions both cmd_001 and cmd_090 — should be kept because max>=cutoff
    p = tmp_root / "queue" / "inbox" / "ashigaru2.yaml"
    _write(
        p,
        """\
        messages:
        - content: 'see cmd_001 and cmd_090 for context'
          from: karo
          id: msg_mixed
          read: true
          timestamp: '2026-01-01T00:00:00'
          type: info
        """,
    )
    res = aq.handle_inbox(p, cutoff=80, dry_run=False)
    assert res.archived_count == 0
    assert res.kept_count == 1


def test_inbox_no_cmd_mention_kept(tmp_root: Path):
    p = tmp_root / "queue" / "inbox" / "x.yaml"
    _write(
        p,
        """\
        messages:
        - content: 'generic chatter'
          from: karo
          id: m
          read: true
          timestamp: '2026-01-01T00:00:00'
          type: info
        """,
    )
    res = aq.handle_inbox(p, cutoff=80, dry_run=False)
    assert res.archived_count == 0


# --- dashboard.md ----------------------------------------------------------


def test_dashboard_section_title_updated(tmp_root: Path):
    p = tmp_root / "dashboard.md"
    _write(
        p,
        """\
        # header
        some text

        ## ✅ 直近の完了（cmd_051以降）
        - **cmd_079** (old)
        - **cmd_080** (boundary kept)
        - **cmd_090** (kept)

        ## other
        footer
        """,
    )
    res = aq.handle_dashboard_md(p, cutoff=80, dry_run=False)
    assert res.archived_count == 1
    content = p.read_text(encoding="utf-8")
    assert "## ✅ 直近の完了（cmd_080以降）" in content
    assert "cmd_079" not in content
    assert "cmd_080" in content
    assert "cmd_090" in content


def test_dashboard_no_section_skipped(tmp_root: Path):
    p = tmp_root / "dashboard.md"
    _write(p, "# header only\n")
    res = aq.handle_dashboard_md(p, cutoff=80, dry_run=False)
    assert res.archived_count == 0
    assert p.read_text(encoding="utf-8") == "# header only\n"


# --- tasks/*.yaml (single-doc) ---------------------------------------------


def test_single_task_old_done_archived(tmp_root: Path):
    p = tmp_root / "queue" / "tasks" / "ashigaru1.yaml"
    _write(
        p,
        """\
        task:
          task_id: subtask_050_foo
          parent_cmd: cmd_050
          description: old work
          status: done
          timestamp: "2026-01-01"
        """,
    )
    res = aq.handle_single_doc_task(p, cutoff=80, dry_run=False)
    assert res.archived_count == 1
    data = _load_rt(p)
    assert data["task"]["status"] == "idle"


def test_single_task_in_progress_never_touched(tmp_root: Path):
    p = tmp_root / "queue" / "tasks" / "ashigaru1.yaml"
    body = """\
    task:
      task_id: subtask_001
      parent_cmd: cmd_001
      status: in_progress
      timestamp: "2026-01-01"
    """
    _write(p, body)
    res = aq.handle_single_doc_task(p, cutoff=999, dry_run=False)
    assert res.archived_count == 0
    assert p.read_text(encoding="utf-8") == textwrap.dedent(body)


# --- gunshi_report (multi-doc) ---------------------------------------------


def test_gunshi_multi_doc_filters(tmp_root: Path):
    p = tmp_root / "queue" / "reports" / "gunshi_report.yaml"
    _write(
        p,
        """\
        worker_id: gunshi
        parent_cmd: cmd_050
        status: done
        result:
          type: qc
          notes: old qc entry
        ---
        worker_id: gunshi
        parent_cmd: cmd_090
        status: done
        result:
          type: qc
          notes: new qc entry
        """,
    )
    res = aq.handle_gunshi_report(p, cutoff=80, dry_run=False)
    assert res.archived_count == 1
    assert res.kept_count == 1
    y = YAML(typ="rt")
    with p.open("r", encoding="utf-8") as f:
        docs = list(y.load_all(f))
    parent_cmds = [d["parent_cmd"] for d in docs if d]
    assert parent_cmds == ["cmd_090"]


# --- end-to-end run summary ------------------------------------------------


def test_run_dry_run_no_changes(tmp_root: Path):
    # Build a minimal scenario
    sk = tmp_root / "queue" / "shogun_to_karo.yaml"
    _write(sk, _sk_yaml([("cmd_001", "done"), ("cmd_090", "done")]))
    dash = tmp_root / "dashboard.md"
    _write(
        dash,
        """\
        ## ✅ 直近の完了（cmd_001以降）
        - **cmd_001** old
        - **cmd_090** new
        """,
    )
    before_sk = sk.read_text(encoding="utf-8")
    before_dash = dash.read_text(encoding="utf-8")
    report = aq.run("cmd_080", dry_run=True)
    assert report.total_archived >= 2
    assert sk.read_text(encoding="utf-8") == before_sk
    assert dash.read_text(encoding="utf-8") == before_dash
