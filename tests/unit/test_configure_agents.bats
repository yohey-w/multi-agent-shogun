#!/usr/bin/env bats

setup() {
  TEST_TMP="$(mktemp -d)"
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  mkdir -p "$TEST_TMP/scripts" "$TEST_TMP/config"
  cp "$PROJECT_ROOT/scripts/configure_agents.py" "$TEST_TMP/scripts/configure_agents.py"
  chmod +x "$TEST_TMP/scripts/configure_agents.py"

  cat > "$TEST_TMP/config/settings.yaml" <<'YAML'
language: ja
shell: bash
cli:
  default: claude
  agents:
    shogun:
      type: claude
      model: opus
      thinking: true
    karo:
      type: claude
      model: sonnet
    gunshi:
      type: claude
      model: opus
    ashigaru1:
      type: claude
      model: sonnet
    ashigaru2:
      type: codex
      model: gpt-5.3-codex
    ashigaru4:
      type: opencode
      model: openrouter/example/stale
      variant: high
YAML
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "configure_agents: CLI種別と足軽数を保存し既存model prefsは保持する" {
  run bash -lc "cd '$TEST_TMP' && python3 scripts/configure_agents.py --default claude --ashigaru-count 3 --shogun codex --karo claude --gunshi opencode --ashigaru1 claude --ashigaru2 codex --ashigaru3 opencode"
  [ "$status" -eq 0 ]

  run python3 - "$TEST_TMP/config/settings.yaml" <<'PY'
import sys, yaml
with open(sys.argv[1], encoding='utf-8') as fh:
    cfg = yaml.safe_load(fh)
agents = cfg["cli"]["agents"]
assert cfg["cli"]["default"] == "claude"
assert agents["shogun"] == {"type": "codex", "model": "opus", "thinking": True}
assert agents["karo"] == {"type": "claude", "model": "sonnet"}
assert agents["gunshi"] == {"type": "opencode", "model": "opus"}
assert agents["ashigaru1"] == {"type": "claude", "model": "sonnet"}
assert agents["ashigaru2"] == {"type": "codex", "model": "gpt-5.3-codex"}
assert agents["ashigaru3"] == {"type": "opencode"}
assert "ashigaru4" not in agents
print("ok")
PY
  [ "$status" -eq 0 ]
}

@test "configure_agents: --reset-model-prefs では詳細model prefsを削除する" {
  run bash -lc "cd '$TEST_TMP' && python3 scripts/configure_agents.py --reset-model-prefs --ashigaru-count 1 --shogun codex --karo claude --gunshi claude --ashigaru1 opencode"
  [ "$status" -eq 0 ]

  run python3 - "$TEST_TMP/config/settings.yaml" <<'PY'
import sys, yaml
with open(sys.argv[1], encoding='utf-8') as fh:
    cfg = yaml.safe_load(fh)
agents = cfg["cli"]["agents"]
assert agents["shogun"] == {"type": "codex"}
assert agents["karo"] == {"type": "claude"}
assert agents["gunshi"] == {"type": "claude"}
assert agents["ashigaru1"] == {"type": "opencode"}
assert "ashigaru2" not in agents
print("ok")
PY
  [ "$status" -eq 0 ]
}

@test "configure_agents: 対話入力は default/core roles/count/ashigaru の順で聞く" {
  run bash -lc "cd '$TEST_TMP' && printf '%s\n' \
    'codex' \
    'claude' \
    'opencode' \
    'kimi' \
    '2' \
    'copilot' \
    'codex' \
    | python3 scripts/configure_agents.py"
  [ "$status" -eq 0 ]

  run python3 - "$output" <<'PY'
import sys
out = sys.argv[1]
labels = [
    "Select cli.default",
    "Select CLI for shogun",
    "Select CLI for karo",
    "Select CLI for gunshi",
    "Number of ashigaru",
    "Select CLI for ashigaru1",
    "Select CLI for ashigaru2",
]
positions = [out.index(label) for label in labels]
assert positions == sorted(positions), positions
PY
  [ "$status" -eq 0 ]

  run python3 - "$TEST_TMP/config/settings.yaml" <<'PY'
import sys, yaml
with open(sys.argv[1], encoding='utf-8') as fh:
    cfg = yaml.safe_load(fh)
agents = cfg["cli"]["agents"]
assert cfg["cli"]["default"] == "codex"
assert agents["shogun"]["type"] == "claude"
assert agents["karo"]["type"] == "opencode"
assert agents["gunshi"]["type"] == "kimi"
assert agents["ashigaru1"]["type"] == "copilot"
assert agents["ashigaru2"]["type"] == "codex"
print("ok")
PY
  [ "$status" -eq 0 ]
}
