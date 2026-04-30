#!/usr/bin/env python3
"""archive_queue.py — archive old done/cancelled cmd entries from queue/ files.

Usage:
  python scripts/archive_queue.py <cutoff_cmd_id> [--dry-run] [--no-commit]

Archives entries where cmd_id < cutoff AND status in {done, cancelled}.
cutoff_cmd_id itself is preserved. pending / in_progress / partial are never touched.
See .claude/skills/archive-queue/SKILL.md for full documentation.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

try:
    from ruamel.yaml import YAML
except ImportError:
    sys.stderr.write(
        "ruamel.yaml is required. Install with: pip install 'ruamel.yaml>=0.18'\n"
    )
    raise

ARCHIVABLE_STATUSES = {"done", "cancelled"}
CMD_ID_RE = re.compile(r"cmd_(\d+)")
CUTOFF_RE = re.compile(r"^cmd_(\d+)$")
ROOT = Path(__file__).resolve().parent.parent


def parse_cmd_id(s: str) -> int:
    m = CUTOFF_RE.fullmatch(s.strip())
    if not m:
        raise ValueError(f"Invalid cmd_id: {s!r} (expected form 'cmd_NNN')")
    return int(m.group(1))


def yaml_indent_4_2() -> YAML:
    y = YAML(typ="rt")
    y.preserve_quotes = True
    y.width = 10_000
    y.indent(mapping=2, sequence=4, offset=2)
    return y


def yaml_indent_2_0() -> YAML:
    y = YAML(typ="rt")
    y.preserve_quotes = True
    y.width = 10_000
    y.indent(mapping=2, sequence=2, offset=0)
    return y


@dataclass
class FileResult:
    path: Path
    archived_count: int = 0
    kept_count: int = 0
    archive_path: Path | None = None
    notes: list[str] = field(default_factory=list)


@dataclass
class RunReport:
    cutoff_id: int
    dry_run: bool
    results: list[FileResult] = field(default_factory=list)

    @property
    def total_archived(self) -> int:
        return sum(r.archived_count for r in self.results)

    def summary(self) -> str:
        mode = "DRY-RUN (no changes)" if self.dry_run else "EXECUTE"
        lines = [
            f"cutoff: cmd_{self.cutoff_id:03d}  (exclusive; entries strictly older AND status in {sorted(ARCHIVABLE_STATUSES)})",
            f"mode:   {mode}",
            "",
            f"{'File':<55} {'archived':>10} {'kept':>6}",
            "-" * 80,
        ]
        for r in self.results:
            try:
                rel = r.path.relative_to(ROOT)
            except ValueError:
                rel = r.path
            lines.append(f"{str(rel):<55} {r.archived_count:>10} {r.kept_count:>6}")
            for n in r.notes:
                lines.append(f"  · {n}")
        lines.append("-" * 80)
        lines.append(f"TOTAL archived entries: {self.total_archived}")
        return "\n".join(lines)


def archive_dir_for_now() -> Path:
    return ROOT / "queue" / "archive" / datetime.now().strftime("%Y-%m")


def append_yaml_list(archive_path: Path, key: str, items: list, y: YAML) -> None:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    if archive_path.exists():
        with archive_path.open("r", encoding="utf-8") as f:
            data = y.load(f) or {}
    else:
        data = {}
    existing = data.get(key) or []
    for it in items:
        existing.append(it)
    data[key] = existing
    with archive_path.open("w", encoding="utf-8") as f:
        y.dump(data, f)


def _eligible(cid_text: str, status: str, cutoff: int) -> bool:
    status = (status or "").strip().lower()
    if status not in ARCHIVABLE_STATUSES:
        return False
    try:
        n = parse_cmd_id(cid_text)
    except ValueError:
        return False
    return n < cutoff


def handle_shogun_to_karo(path: Path, cutoff: int, dry_run: bool) -> FileResult:
    res = FileResult(path=path)
    if not path.exists():
        res.notes.append("missing — skipped")
        return res
    y = yaml_indent_4_2()
    with path.open("r", encoding="utf-8") as f:
        data = y.load(f)
    if not data or "commands" not in data:
        res.notes.append("no `commands:` key — skipped")
        return res
    commands = data["commands"]
    before_len = len(commands)
    keep_idx: list[int] = []
    archive_idx: list[int] = []
    for i, entry in enumerate(commands):
        cid = str(entry.get("id", ""))
        status = str(entry.get("status") or "")
        if _eligible(cid, status, cutoff):
            archive_idx.append(i)
        else:
            keep_idx.append(i)
    archive_items = [commands[i] for i in archive_idx]
    res.archived_count = len(archive_items)
    res.kept_count = len(keep_idx)
    if not dry_run and archive_items:
        append_yaml_list(
            archive_dir_for_now() / "shogun_to_karo.yaml",
            "commands",
            archive_items,
            y,
        )
        res.archive_path = archive_dir_for_now() / "shogun_to_karo.yaml"
        # delete from highest index first to preserve indices
        for i in sorted(archive_idx, reverse=True):
            del commands[i]
        tmp = path.with_suffix(path.suffix + ".tmp")
        with tmp.open("w", encoding="utf-8") as f:
            y.dump(data, f)
        # verify
        with tmp.open("r", encoding="utf-8") as f:
            check = y.load(f)
        after_len = len(check.get("commands") or [])
        if after_len + len(archive_items) != before_len:
            tmp.unlink(missing_ok=True)
            raise RuntimeError(
                f"Entry count mismatch for {path}: "
                f"before={before_len} kept={after_len} archived={len(archive_items)}"
            )
        tmp.replace(path)
    return res


def handle_inbox(path: Path, cutoff: int, dry_run: bool) -> FileResult:
    res = FileResult(path=path)
    if not path.exists():
        res.notes.append("missing — skipped")
        return res
    y = yaml_indent_2_0()
    with path.open("r", encoding="utf-8") as f:
        data = y.load(f)
    if not data or "messages" not in data:
        res.notes.append("no `messages:` — skipped")
        return res
    messages = data["messages"]
    before_len = len(messages)
    archive_idx: list[int] = []
    kept = 0
    for i, m in enumerate(messages):
        content = str(m.get("content") or "")
        read_flag = bool(m.get("read"))
        cmd_nums = [int(x) for x in CMD_ID_RE.findall(content)]
        # safe eligibility: read:true + references only cmds strictly older than cutoff
        # (if content mentions any cmd >= cutoff, keep — conservative)
        if read_flag and cmd_nums and max(cmd_nums) < cutoff:
            archive_idx.append(i)
        else:
            kept += 1
    archive_items = [messages[i] for i in archive_idx]
    res.archived_count = len(archive_items)
    res.kept_count = kept
    if not dry_run and archive_items:
        archive_path = archive_dir_for_now() / f"inbox_{path.stem}.yaml"
        append_yaml_list(archive_path, "messages", archive_items, y)
        res.archive_path = archive_path
        for i in sorted(archive_idx, reverse=True):
            del messages[i]
        tmp = path.with_suffix(path.suffix + ".tmp")
        with tmp.open("w", encoding="utf-8") as f:
            y.dump(data, f)
        with tmp.open("r", encoding="utf-8") as f:
            check = y.load(f)
        after_len = len(check.get("messages") or [])
        if after_len + len(archive_items) != before_len:
            tmp.unlink(missing_ok=True)
            raise RuntimeError(
                f"Entry count mismatch for {path}: "
                f"before={before_len} kept={after_len} archived={len(archive_items)}"
            )
        tmp.replace(path)
    return res


def handle_gunshi_report(path: Path, cutoff: int, dry_run: bool) -> FileResult:
    res = FileResult(path=path)
    if not path.exists():
        res.notes.append("missing — skipped")
        return res
    y = yaml_indent_4_2()
    with path.open("r", encoding="utf-8") as f:
        docs = list(y.load_all(f))
    keep: list[Any] = []
    archive: list[Any] = []
    for d in docs:
        if d is None:
            keep.append(d)
            continue
        pc = str(d.get("parent_cmd") or "")
        status = str(d.get("status") or "")
        if pc and _eligible(pc, status, cutoff):
            archive.append(d)
        else:
            keep.append(d)
    res.archived_count = len(archive)
    res.kept_count = sum(1 for k in keep if k is not None)
    if not dry_run and archive:
        archive_path = archive_dir_for_now() / "gunshi_report.yaml"
        archive_path.parent.mkdir(parents=True, exist_ok=True)
        existing_docs: list[Any] = []
        if archive_path.exists():
            with archive_path.open("r", encoding="utf-8") as f:
                existing_docs = list(y.load_all(f))
        merged = existing_docs + archive
        with archive_path.open("w", encoding="utf-8") as f:
            y.dump_all(merged, f)
        res.archive_path = archive_path
        tmp = path.with_suffix(path.suffix + ".tmp")
        with tmp.open("w", encoding="utf-8") as f:
            y.dump_all(keep, f)
        with tmp.open("r", encoding="utf-8") as f:
            check = list(y.load_all(f))
        if len(check) + len(archive) != len(docs):
            tmp.unlink(missing_ok=True)
            raise RuntimeError(
                f"Gunshi doc count mismatch: before={len(docs)} kept={len(check)} archived={len(archive)}"
            )
        tmp.replace(path)
    return res


def handle_single_doc_task(path: Path, cutoff: int, dry_run: bool) -> FileResult:
    res = FileResult(path=path)
    if not path.exists():
        res.notes.append("missing — skipped")
        return res
    y = yaml_indent_4_2()
    with path.open("r", encoding="utf-8") as f:
        data = y.load(f)
    if not data or "task" not in data or not data["task"]:
        res.notes.append("no task — skipped")
        return res
    task = data["task"]
    pc = str(task.get("parent_cmd") or "")
    status = str(task.get("status") or "")
    if not (pc and _eligible(pc, status, cutoff)):
        res.notes.append(f"status={status!r} parent_cmd={pc!r} — kept")
        return res
    res.archived_count = 1
    if not dry_run:
        archive_path = archive_dir_for_now() / f"tasks_{path.stem}.yaml"
        append_yaml_list(archive_path, "archived_tasks", [data], y)
        res.archive_path = archive_path
        stub = {"task": {"status": "idle"}}
        with path.open("w", encoding="utf-8") as f:
            y.dump(stub, f)
    return res


def handle_single_doc_report(path: Path, cutoff: int, dry_run: bool) -> FileResult:
    res = FileResult(path=path)
    if not path.exists():
        res.notes.append("missing — skipped")
        return res
    y = yaml_indent_4_2()
    with path.open("r", encoding="utf-8") as f:
        data = y.load(f)
    if not data:
        res.notes.append("empty — skipped")
        return res
    nested = "report" in data and isinstance(data["report"], dict)
    core = data["report"] if nested else data
    pc = str(core.get("parent_cmd") or "")
    status = str(core.get("status") or "")
    # normalize ashigaru7-style "completed" → "done"
    if status.strip().lower() == "completed":
        status = "done"
    if not (pc and _eligible(pc, status, cutoff)):
        res.notes.append(f"status={status!r} parent_cmd={pc!r} — kept")
        return res
    res.archived_count = 1
    if not dry_run:
        archive_path = archive_dir_for_now() / f"reports_{path.stem}.yaml"
        append_yaml_list(archive_path, "archived_reports", [data], y)
        res.archive_path = archive_path
        if nested:
            stub: Any = {"report": {"status": "idle"}}
        else:
            stub = {
                "worker_id": core.get("worker_id") or path.stem.replace("_report", ""),
                "status": "idle",
            }
        with path.open("w", encoding="utf-8") as f:
            y.dump(stub, f)
    return res


DASHBOARD_SECTION_RE = re.compile(r"^## ✅ 直近の完了（cmd_(\d+)以降）\s*$")
DASHBOARD_LINE_RE = re.compile(r"^- \*\*cmd_(\d+)\*\*")


def handle_dashboard_md(path: Path, cutoff: int, dry_run: bool) -> FileResult:
    res = FileResult(path=path)
    if not path.exists():
        res.notes.append("missing — skipped")
        return res
    text = path.read_text(encoding="utf-8")
    trailing_newline = text.endswith("\n")
    lines = text.splitlines()
    start_idx = None
    for i, ln in enumerate(lines):
        if DASHBOARD_SECTION_RE.match(ln):
            start_idx = i
            break
    if start_idx is None:
        res.notes.append("no ✅ section — skipped")
        return res
    end_idx = len(lines)
    for j in range(start_idx + 1, len(lines)):
        if lines[j].startswith("## "):
            end_idx = j
            break
    body = lines[start_idx + 1 : end_idx]
    keep_body: list[str] = []
    archived: list[str] = []
    new_min: int | None = None
    for bl in body:
        m = DASHBOARD_LINE_RE.match(bl)
        if m:
            n = int(m.group(1))
            if n < cutoff:
                archived.append(bl)
                continue
            if new_min is None or n < new_min:
                new_min = n
        keep_body.append(bl)
    res.archived_count = len(archived)
    res.kept_count = sum(1 for bl in keep_body if DASHBOARD_LINE_RE.match(bl))
    if not archived:
        res.notes.append("no cmd lines < cutoff in ✅ section")
        return res
    if not dry_run:
        new_since = new_min if new_min is not None else cutoff
        new_header = f"## ✅ 直近の完了（cmd_{new_since:03d}以降）"
        new_lines = lines[:start_idx] + [new_header] + keep_body + lines[end_idx:]
        archive_path = archive_dir_for_now() / "archive_dashboard.md"
        archive_path.parent.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().strftime("%Y-%m-%d %H:%M")
        with archive_path.open("a", encoding="utf-8") as f:
            f.write(f"\n<!-- archived {ts} from dashboard.md, cutoff cmd_{cutoff:03d} -->\n")
            for al in archived:
                f.write(al + "\n")
        res.archive_path = archive_path
        out = "\n".join(new_lines) + ("\n" if trailing_newline else "")
        path.write_text(out, encoding="utf-8")
    return res


def iter_inbox_files() -> Iterable[Path]:
    return sorted((ROOT / "queue" / "inbox").glob("*.yaml"))


def iter_task_files() -> Iterable[Path]:
    return sorted((ROOT / "queue" / "tasks").glob("*.yaml"))


def iter_ashigaru_report_files() -> Iterable[Path]:
    d = ROOT / "queue" / "reports"
    return sorted(p for p in d.glob("*_report.yaml") if p.name != "gunshi_report.yaml")


def git_commit(cutoff: int, extra_paths: list[str] | None = None) -> str | None:
    paths = ["queue/archive", "queue/shogun_to_karo.yaml", "queue/inbox",
            "queue/tasks", "queue/reports", "dashboard.md"]
    if extra_paths:
        paths.extend(extra_paths)
    try:
        subprocess.run(
            ["git", "-C", str(ROOT), "add", "--", *paths],
            check=True,
        )
        rc = subprocess.run(
            ["git", "-C", str(ROOT), "diff", "--cached", "--quiet"],
        ).returncode
        if rc == 0:
            print("No staged changes — skipping commit.")
            return None
        msg = f"chore(archive): archive cmds < cmd_{cutoff:03d}"
        subprocess.run(
            ["git", "-C", str(ROOT), "commit", "-m", msg],
            check=True,
        )
        out = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
            check=True, capture_output=True, text=True,
        )
        return out.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"git commit failed: {e}", file=sys.stderr)
        return None


def run(cutoff_id_str: str, dry_run: bool) -> RunReport:
    cutoff = parse_cmd_id(cutoff_id_str)
    report = RunReport(cutoff_id=cutoff, dry_run=dry_run)
    report.results.append(
        handle_shogun_to_karo(ROOT / "queue" / "shogun_to_karo.yaml", cutoff, dry_run)
    )
    report.results.append(handle_dashboard_md(ROOT / "dashboard.md", cutoff, dry_run))
    report.results.append(
        handle_gunshi_report(ROOT / "queue" / "reports" / "gunshi_report.yaml", cutoff, dry_run)
    )
    for p in iter_inbox_files():
        report.results.append(handle_inbox(p, cutoff, dry_run))
    for p in iter_task_files():
        report.results.append(handle_single_doc_task(p, cutoff, dry_run))
    for p in iter_ashigaru_report_files():
        report.results.append(handle_single_doc_report(p, cutoff, dry_run))
    return report


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Archive old done/cancelled cmd entries from queue/ files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python scripts/archive_queue.py cmd_080 --dry-run\n"
            "  python scripts/archive_queue.py cmd_080\n"
        ),
    )
    ap.add_argument(
        "cutoff_cmd_id",
        help="e.g. 'cmd_080' — entries with cmd_id strictly less AND status in {done, cancelled} are archived. cutoff itself is preserved.",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="No file changes — only report counts per file.",
    )
    ap.add_argument(
        "--no-commit",
        action="store_true",
        help="Skip git commit after archiving (useful for manual review).",
    )
    args = ap.parse_args()

    try:
        report = run(args.cutoff_cmd_id, args.dry_run)
    except Exception as e:
        print(f"FATAL: {e}", file=sys.stderr)
        return 2

    print(report.summary())

    if not args.dry_run and report.total_archived > 0 and not args.no_commit:
        sha = git_commit(report.cutoff_id)
        if sha:
            print(f"\ngit commit: {sha}")
        else:
            print("\ngit commit: (skipped / failed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
