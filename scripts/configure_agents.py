#!/usr/bin/env python3
"""Configure Shogun agent CLI assignments with a small CUI.

This script edits only the coarse formation choices:

- cli.default
- cli.agents.<role>.type
- the active ashigaru range represented in cli.agents

Model, variant, and thinking fields are preserved by default so existing
settings.yaml model routing keeps working.
"""

from __future__ import annotations

import argparse
import copy
import re
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SETTINGS = ROOT / "config/settings.yaml"
ALLOWED_CLIS = ("claude", "codex", "copilot", "kimi", "opencode")
CORE_ROLES = ("shogun", "karo", "gunshi")
ASHIGARU_RE = re.compile(r"^ashigaru([1-9][0-9]*)$")
MODEL_PREF_KEYS = ("model", "variant", "thinking", "reasoning_effort", "recommended_model")
DEFAULT_ASHIGARU_COUNT = 7


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    return data if isinstance(data, dict) else {}


def save_yaml(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        yaml.safe_dump(data, fh, sort_keys=False, allow_unicode=True)


def normalize_cli(value: str, *, field: str) -> str:
    normalized = (value or "").strip().lower()
    if normalized not in ALLOWED_CLIS:
        allowed = ", ".join(ALLOWED_CLIS)
        raise SystemExit(f"{field}: unsupported CLI '{value}'. Allowed: {allowed}")
    return normalized


def normalize_count(value: int) -> int:
    if value < 1:
        raise SystemExit("--ashigaru-count must be 1 or greater")
    return value


def ensure_cli_sections(cfg: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    cli = cfg.get("cli")
    if not isinstance(cli, dict):
        cli = {}
        cfg["cli"] = cli
    agents = cli.get("agents")
    if not isinstance(agents, dict):
        agents = {}
        cli["agents"] = agents
    return cli, agents


def current_cli(cfg: dict[str, Any], role: str, fallback: str) -> str:
    cli = cfg.get("cli") if isinstance(cfg.get("cli"), dict) else {}
    agents = cli.get("agents") if isinstance(cli.get("agents"), dict) else {}
    agent_cfg = agents.get(role) if isinstance(agents, dict) else None

    if isinstance(agent_cfg, dict):
        value = str(agent_cfg.get("type") or "").strip().lower()
        if value in ALLOWED_CLIS:
            return value
    elif isinstance(agent_cfg, str):
        value = agent_cfg.strip().lower()
        if value in ALLOWED_CLIS:
            return value

    default_cli = str(cli.get("default") or "").strip().lower() if isinstance(cli, dict) else ""
    if default_cli in ALLOWED_CLIS:
        return default_cli
    return fallback


def current_ashigaru_count(cfg: dict[str, Any]) -> int:
    cli = cfg.get("cli") if isinstance(cfg.get("cli"), dict) else {}
    agents = cli.get("agents") if isinstance(cli.get("agents"), dict) else {}
    if not isinstance(agents, dict) or "karo" not in agents:
        return DEFAULT_ASHIGARU_COUNT

    numbers = []
    for role in agents:
        if not isinstance(role, str):
            continue
        match = ASHIGARU_RE.match(role)
        if match:
            numbers.append(int(match.group(1)))
    if not numbers:
        return DEFAULT_ASHIGARU_COUNT
    return max(numbers)


def prompt_choice(label: str, default: str) -> str:
    while True:
        print("")
        print(label)
        for idx, option in enumerate(ALLOWED_CLIS, start=1):
            suffix = " [default]" if option == default else ""
            print(f"  {idx}) {option}{suffix}")
        raw = input("> ").strip()
        if not raw:
            return default
        if raw.isdigit():
            idx = int(raw)
            if 1 <= idx <= len(ALLOWED_CLIS):
                return ALLOWED_CLIS[idx - 1]
        raw = raw.lower()
        if raw in ALLOWED_CLIS:
            return raw
        print("Input error: choose a CLI type.")


def prompt_count(default: int) -> int:
    while True:
        print("")
        raw = input(f"Number of ashigaru (1 or more) [default: {default}]: ").strip()
        if not raw:
            return default
        if raw.isdigit() and int(raw) >= 1:
            return int(raw)
        print("Input error: ashigaru count must be an integer greater than or equal to 1.")


def set_role_cli(agents: dict[str, Any], role: str, cli_type: str, *, reset_model_prefs: bool) -> None:
    existing = agents.get(role)
    if isinstance(existing, dict):
        role_cfg = copy.deepcopy(existing)
    else:
        role_cfg = {}
    role_cfg["type"] = cli_type
    if reset_model_prefs:
        for key in MODEL_PREF_KEYS:
            role_cfg.pop(key, None)
    agents[role] = role_cfg


def configure(
    cfg: dict[str, Any],
    *,
    default_cli: str,
    ashigaru_count: int,
    role_clis: dict[str, str],
    reset_model_prefs: bool,
) -> dict[str, Any]:
    cli, agents = ensure_cli_sections(cfg)
    cli["default"] = default_cli

    for role in CORE_ROLES:
        set_role_cli(agents, role, role_clis.get(role, default_cli), reset_model_prefs=reset_model_prefs)

    for i in range(1, ashigaru_count + 1):
        role = f"ashigaru{i}"
        set_role_cli(agents, role, role_clis.get(role, default_cli), reset_model_prefs=reset_model_prefs)

    for role in list(agents.keys()):
        if not isinstance(role, str):
            continue
        match = ASHIGARU_RE.match(role)
        if match and int(match.group(1)) > ashigaru_count:
            agents.pop(role, None)

    return cfg


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Configure Shogun role CLI types and ashigaru count.")
    parser.add_argument("--settings", default=str(DEFAULT_SETTINGS), help="settings.yaml path")
    parser.add_argument("--default", choices=ALLOWED_CLIS, help="cli.default")
    parser.add_argument("--ashigaru-count", type=int, help="number of active ashigaru")
    parser.add_argument("--ashigaru-cli", choices=ALLOWED_CLIS, help="default CLI for unspecified ashigaru")
    parser.add_argument(
        "--reset-model-prefs",
        action="store_true",
        help="remove model/variant/thinking fields for configured roles",
    )
    parser.add_argument("--dry-run", action="store_true", help="print updated YAML without writing")
    for role in CORE_ROLES:
        parser.add_argument(f"--{role}", choices=ALLOWED_CLIS, help=f"{role} CLI type")
    for i in range(1, 33):
        parser.add_argument(f"--ashigaru{i}", choices=ALLOWED_CLIS, help=f"ashigaru{i} CLI type")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    settings_path = Path(args.settings)
    cfg = load_yaml(settings_path)

    provided_any = any(
        getattr(args, name) is not None
        for name in ("default", "ashigaru_count", "ashigaru_cli", *CORE_ROLES)
    ) or any(getattr(args, f"ashigaru{i}") is not None for i in range(1, 33))

    if args.default:
        default_cli = normalize_cli(args.default, field="--default")
    elif provided_any:
        default_cli = current_cli(cfg, "shogun", "claude")
    else:
        default_cli = current_cli(cfg, "shogun", "claude")

    ashigaru_count = normalize_count(args.ashigaru_count) if args.ashigaru_count else current_ashigaru_count(cfg)

    role_clis: dict[str, str] = {}
    if provided_any:
        for role in CORE_ROLES:
            value = getattr(args, role)
            role_clis[role] = normalize_cli(value, field=f"--{role}") if value else current_cli(cfg, role, default_cli)
        ashigaru_default = args.ashigaru_cli or default_cli
        for i in range(1, ashigaru_count + 1):
            role = f"ashigaru{i}"
            value = getattr(args, role)
            role_clis[role] = normalize_cli(value, field=f"--{role}") if value else current_cli(cfg, role, ashigaru_default)
    else:
        print("=== Shogun agent configurator ===")
        print(f"settings: {settings_path}")
        default_cli = prompt_choice("Select cli.default", default_cli)
        for role in CORE_ROLES:
            role_clis[role] = prompt_choice(f"Select CLI for {role}", current_cli(cfg, role, default_cli))
        ashigaru_count = prompt_count(ashigaru_count)
        for i in range(1, ashigaru_count + 1):
            role = f"ashigaru{i}"
            role_clis[role] = prompt_choice(f"Select CLI for {role}", current_cli(cfg, role, default_cli))

    updated = configure(
        cfg,
        default_cli=default_cli,
        ashigaru_count=ashigaru_count,
        role_clis=role_clis,
        reset_model_prefs=args.reset_model_prefs,
    )

    if args.dry_run:
        print(yaml.safe_dump(updated, sort_keys=False, allow_unicode=True), end="")
    else:
        save_yaml(settings_path, updated)
        print(f"[OK] updated {settings_path}")
        print("[OK] model/variant/thinking fields were preserved")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
