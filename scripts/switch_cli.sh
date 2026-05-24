#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# switch_cli.sh — エージェントのCLIセッションを安全に切り替える
#
# Usage:
#   bash scripts/switch_cli.sh <agent_id> [--type <cli_type>] [--model <model_name>] [--variant <variant>]
#
# Examples:
#   # settings.yaml の現在値で再起動（CLI種別/モデル変更なし）
#   bash scripts/switch_cli.sh ashigaru3
#
#   # Codex Spark → Claude Sonnet に切替
#   bash scripts/switch_cli.sh ashigaru3 --type claude --model claude-sonnet-4-6
#
#   # OpenCode で provider/model を直接指定（role 定義は --agent、モデル変更は再起動で反映）
#   bash scripts/switch_cli.sh ashigaru3 --type opencode --model openai/gpt-5.4-mini
#
#   # OpenCode provider-specific reasoning variant
#   bash scripts/switch_cli.sh ashigaru3 --type opencode --model openrouter/minimax/minimax-m2.5 --variant xhigh
#
#   # 同一CLI内でモデルだけ変更（Sonnet → Opus）
#   bash scripts/switch_cli.sh ashigaru3 --model claude-opus-4-6
#
#   # 全足軽を一括切替
#   for i in $(seq 1 7); do bash scripts/switch_cli.sh ashigaru$i --type claude --model claude-sonnet-4-6; done
#
# Flow:
#   1. (Optional) settings.yaml を更新
#   2. 現在のCLIに /exit を送信
#   3. シェルプロンプトの復帰を待機
#   4. build_cli_command() で新CLIコマンドを構築
#   5. tmux send-keys で新CLIを起動
#   6. tmux pane metadata を更新（@agent_cli, @model_name）
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETTINGS_FILE="${PROJECT_ROOT}/config/settings.yaml"
LOG_FILE="${PROJECT_ROOT}/logs/switch_cli.log"

# cli_adapter.sh をロード
source "${PROJECT_ROOT}/lib/cli_adapter.sh"
source "${PROJECT_ROOT}/lib/agent_registry.sh"

# ─── ログ ───
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [switch_cli] $*"
    echo "$msg" >&2
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# ─── Usage ───
usage() {
    echo "Usage: $0 <agent_id> [--type <cli_type>] [--model <model_name>] [--variant <variant>]"
    echo ""
    echo "  agent_id   Agent configured in config/settings.yaml (e.g. karo, ashigaru1, gunshi)"
    echo "  --type     claude | codex | copilot | kimi | opencode | cursor"
    echo "  --model    claude-sonnet-4-6 | claude-opus-4-6 | gpt-5.3-codex | openai/gpt-5.4-mini | etc."
    echo "  --variant  OpenCode model variant such as xhigh, high, max, minimal"
    echo ""
    echo "If --type/--model omitted, uses current settings.yaml values."
    exit 1
}

# ─── Agent ID → tmux pane 解決 ───
# @agent_id メタデータから動的にペインを検索する（ペイン番号のズレに対応）
# フォールバック: メタデータが見つからない場合は従来の固定マッピングを使用
resolve_pane() {
    local agent_id="$1"

    # Phase 1: @agent_id メタデータから動的検索
    local pane_count
    pane_count=$(tmux list-panes -t "multiagent:agents" 2>/dev/null | wc -l)
    if [[ "$pane_count" -gt 0 ]]; then
        for i in $(seq 0 $((pane_count - 1))); do
            local aid
            aid=$(tmux display-message -t "multiagent:agents.$i" -p '#{@agent_id}' 2>/dev/null)
            if [[ "$aid" == "$agent_id" ]]; then
                echo "multiagent:agents.$i"
                return 0
            fi
        done
        log "WARN: @agent_id=$agent_id not found in any pane. Falling back to fixed mapping."
    fi

    # Phase 2: フォールバック（settings.yaml の編成順から解決）
    local pane_base
    pane_base=$(tmux show-options -t multiagent -v @pane_base 2>/dev/null || echo "0")

    if agent_registry_multiagent_pane_for_agent "$agent_id" "$pane_base"; then
        return 0
    fi

    log "ERROR: Unknown agent_id: $agent_id"
    return 1
}

# ─── settings.yaml 更新 (Python使用) ───
update_settings_yaml() {
    local agent_id="$1"
    local new_type="${2:-}"
    local new_model="${3:-}"
    local new_variant="${4:-}"

    if [[ -z "$new_type" && -z "$new_model" && -z "$new_variant" ]]; then
        return 0
    fi

    log "Updating settings.yaml: ${agent_id} → type=${new_type:-<unchanged>}, model=${new_model:-<unchanged>}, variant=${new_variant:-<unchanged>}"

    "${PROJECT_ROOT}/.venv/bin/python3" << PYEOF
import yaml, sys, os, datetime

settings_path = "${SETTINGS_FILE}"
agent_id = "${agent_id}"
new_type = "${new_type}" or None
new_model = "${new_model}" or None
new_variant = "${new_variant}" or None

with open(settings_path, 'r', encoding='utf-8') as f:
    content = f.read()

with open(settings_path, 'r', encoding='utf-8') as f:
    data = yaml.safe_load(f) or {}

cli = data.setdefault('cli', {})
agents = cli.setdefault('agents', {})
agent_cfg = agents.get(agent_id)
if not isinstance(agent_cfg, dict):
    agent_cfg = {}
    agents[agent_id] = agent_cfg

timestamp = datetime.datetime.now().strftime('%Y-%m-%d')
comment = f"# {timestamp}: switch_cli.sh による切替"

if new_type:
    agent_cfg['type'] = new_type
if new_model:
    agent_cfg['model'] = new_model
if new_variant:
    agent_cfg['variant'] = new_variant

data['cli']['agents'][agent_id] = agent_cfg

# コメント保持のため、対象エージェント行だけsedで置換する方が安全だが
# 完全性のためyaml.dumpを使用。コメントは失われる。
# → 代わりにsed的なアプローチ: 対象ブロックだけ書き換える

# Simple approach: read lines, find agent block, replace
lines = content.split('\n')
new_lines = []
in_agent_block = False
agent_indent = None
skip_until_next = False
agent_block_found = False

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.lstrip()

    # Detect our agent's block start
    if stripped.startswith(f'{agent_id}:'):
        agent_block_found = True
        in_agent_block = True
        agent_indent = len(line) - len(stripped)
        new_lines.append(line)
        # Write the updated fields
        inner_indent = ' ' * (agent_indent + 2)
        if new_type:
            new_lines.append(f'{inner_indent}type: {new_type}')
        if new_model:
            new_lines.append(f'{inner_indent}model: {new_model}  {comment}')
        if new_variant:
            new_lines.append(f'{inner_indent}variant: {new_variant}  {comment}')
        # Skip old sub-fields
        i += 1
        while i < len(lines):
            next_line = lines[i]
            next_stripped = next_line.lstrip()
            if next_stripped == '' or next_stripped.startswith('#'):
                # Keep blank lines and comments between blocks
                if next_stripped.startswith('#') and len(next_line) - len(next_stripped) > agent_indent:
                    i += 1
                    continue
                break
            next_indent = len(next_line) - len(next_stripped)
            if next_indent <= agent_indent:
                break  # Next agent or section
            i += 1
        in_agent_block = False
        continue
    else:
        new_lines.append(line)
    i += 1

if not agent_block_found:
    # Agent block not found: fall back to yaml.dump (adds new block, comments lost)
    with open(settings_path, 'w', encoding='utf-8') as f:
        yaml.dump(data, f, allow_unicode=True, default_flow_style=False)
else:
    with open(settings_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
        if not content.endswith('\n'):
            pass
        else:
            f.write('\n') if not '\n'.join(new_lines).endswith('\n') else None

print("OK")
PYEOF
}

# ─── OpenCode runtime agent frontmatter 同期 ───
# OpenCode TUI は `opencode run` と違って --variant を受け付けない。
# provider固有variantは git-ignored の .opencode/agents/<agent>-runtime.md に同期する。
sync_opencode_agent_frontmatter() {
    local agent_id="$1"
    local model="${2:-}"
    local variant="${3:-}"
    local base_file="${PROJECT_ROOT}/.opencode/agents/${agent_id}.md"
    local runtime_file="${PROJECT_ROOT}/.opencode/agents/${agent_id}-runtime.md"
    local normalized_model

    [[ -f "$base_file" ]] || return 0

    normalized_model="$(normalize_opencode_model "$model")"

    if [[ -z "$variant" ]]; then
        rm -f "$runtime_file"
        return 0
    fi

    log "Syncing OpenCode runtime agent: ${agent_id}-runtime → model=${normalized_model:-<unset>}, variant=${variant}"

    "${PROJECT_ROOT}/.venv/bin/python3" - "$base_file" "$runtime_file" "$normalized_model" "$variant" <<'PYEOF'
import sys
from pathlib import Path

import yaml

source = Path(sys.argv[1])
dest = Path(sys.argv[2])
model = sys.argv[3] or None
variant = sys.argv[4] or None

text = source.read_text(encoding="utf-8")
if not text.startswith("---\n"):
    raise SystemExit(0)

parts = text.split("---", 2)
if len(parts) < 3:
    raise SystemExit(0)

body = parts[2]
route = {}
if model:
    route["model"] = model
if variant:
    route["variant"] = variant
route_lines = yaml.safe_dump(route, allow_unicode=True, sort_keys=False).splitlines() if route else []

frontmatter_lines = parts[1].lstrip("\n").splitlines()
new_lines = []
inserted = False
for line in frontmatter_lines:
    stripped = line.lstrip()
    indent = len(line) - len(stripped)
    if indent == 0 and (stripped.startswith("model:") or stripped.startswith("variant:")):
        continue
    if not inserted and indent == 0 and stripped.startswith("permission:"):
        new_lines.extend(route_lines)
        inserted = True
    new_lines.append(line)

if not inserted:
    new_lines.extend(route_lines)

frontmatter_text = "\n".join(new_lines).rstrip()

dest.write_text(f"---\n{frontmatter_text}\n---{body}", encoding="utf-8")
PYEOF
}

# ─── 現在のCLI種別を取得（tmux metadata） ───
get_current_pane_cli() {
    local pane="$1"
    tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null | tr -d '[:space:]' || echo "claude"
}

# ─── /exit送信 ───
send_exit() {
    local pane="$1"
    local current_cli="$2"

    log "Sending exit command to ${pane} (current CLI: ${current_cli})"

    case "$current_cli" in
        codex)
            # Codex: suggestion UI dismissal → Ctrl-C → /exit
            tmux send-keys -t "$pane" Escape 2>/dev/null || true
            sleep 0.3
            tmux send-keys -t "$pane" C-c 2>/dev/null || true
            sleep 0.5
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || true
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || true
            ;;
        claude)
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || true
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || true
            ;;
        copilot|kimi)
            tmux send-keys -t "$pane" C-c 2>/dev/null || true
            sleep 0.5
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || true
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || true
            ;;
        cursor)
            tmux send-keys -t "$pane" "/quit" 2>/dev/null || true
            sleep 0.3
            tmux send-keys -t "$pane" "" Enter 2>/dev/null || true
            ;;
        *)
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || true
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || true
            ;;
    esac
}

# ─── シェルプロンプト待ち（最大15秒） ───
wait_for_shell_prompt() {
    local pane="$1"
    local max_wait=15
    local waited=0

    log "Waiting for shell prompt on ${pane}..."

    while [ "$waited" -lt "$max_wait" ]; do
        sleep 1
        waited=$((waited + 1))

        local last_lines
        last_lines=$(tmux capture-pane -t "$pane" -p 2>/dev/null | grep -v '^$' | tail -3)

        # シェルプロンプトの検出パターン
        # PS1にはカスタムプロンプト（shutsujin由来）や標準的な$/%が含まれる
        if echo "$last_lines" | grep -qE '[\$%#❯►] *$'; then
            log "Shell prompt detected after ${waited}s"
            return 0
        fi

        # "exit" / "Bye" 等のCLI終了メッセージを検出
        if echo "$last_lines" | grep -qiE '(bye|goodbye|exiting|exit)'; then
            sleep 1  # 終了メッセージの後、プロンプトが出るまで少し待つ
            log "CLI exit message detected after ${waited}s"
            return 0
        fi
    done

    log "WARN: Shell prompt not detected after ${max_wait}s. Proceeding anyway."
    return 0  # タイムアウトしても続行（最悪でもコマンドが送られるだけ）
}

# ─── モデル表示名の正規化（cli_adapter.sh の get_model_display_name を使用） ───
# get_model_display_name は cli_adapter.sh から source 済み

# ─── tmux pane metadata 更新 ───
update_pane_metadata() {
    local pane="$1"
    local new_cli_type="$2"
    local display_name="$3"

    log "Updating pane metadata: @agent_cli=${new_cli_type}, @model_name=${display_name}"

    tmux set-option -p -t "$pane" @agent_cli "$new_cli_type" 2>/dev/null || true
    tmux set-option -p -t "$pane" @model_name "$display_name" 2>/dev/null || true
    tmux select-pane -t "$pane" -T "$display_name" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════
# メイン処理
# ═══════════════════════════════════════════════════════════════

# 引数パース
if [ $# -lt 1 ]; then
    usage
fi

# --help が第1引数の場合
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
fi

AGENT_ID="$1"
shift

NEW_TYPE=""
NEW_MODEL=""
NEW_VARIANT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --type)
            NEW_TYPE="$2"
            shift 2
            ;;
        --model)
            NEW_MODEL="$2"
            shift 2
            ;;
        --variant)
            NEW_VARIANT="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# バリデーション
if [[ -n "$NEW_TYPE" ]] && ! _cli_adapter_is_valid_cli "$NEW_TYPE"; then
    log "ERROR: Invalid CLI type: ${NEW_TYPE}. Allowed: ${CLI_ADAPTER_ALLOWED_CLIS}"
    exit 1
fi

# Step 0: pane解決
PANE_TARGET=$(resolve_pane "$AGENT_ID")
if [ -z "$PANE_TARGET" ]; then
    exit 1
fi
log "=== Starting CLI switch for ${AGENT_ID} (pane: ${PANE_TARGET}) ==="

# Step 0.5: --model指定時に--type未指定なら、CLI種別を安全に補完する
if [[ -n "$NEW_MODEL" && -z "$NEW_TYPE" ]]; then
    case "$NEW_MODEL" in
        gpt-5.3-codex*|gpt-5-codex*)
            NEW_TYPE="codex"
            log "Auto-inferred type=codex from model=${NEW_MODEL}"
            ;;
        */*)
            if [[ "$(get_cli_type "$AGENT_ID")" == "opencode" ]]; then
                NEW_TYPE="opencode"
                log "Preserving type=opencode for provider-qualified model=${NEW_MODEL}"
            else
                log "ERROR: provider-qualified model IDs are ambiguous without --type; use --type opencode --model ${NEW_MODEL}"
                exit 1
            fi
            ;;
        claude-*)
            NEW_TYPE="claude"
            log "Auto-inferred type=claude from model=${NEW_MODEL}"
            ;;
    esac
fi

# Step 1: settings.yaml 更新（--type/--model/--variant 指定時のみ）
if [[ -n "$NEW_TYPE" || -n "$NEW_MODEL" || -n "$NEW_VARIANT" ]]; then
    update_settings_yaml "$AGENT_ID" "$NEW_TYPE" "$NEW_MODEL" "$NEW_VARIANT"
fi

# Step 2: 切替後のCLI情報を取得（settings.yaml反映後）
TARGET_CLI_TYPE=$(get_cli_type "$AGENT_ID")
TARGET_MODEL=$(get_agent_model "$AGENT_ID")
TARGET_VARIANT=$(_cli_adapter_read_yaml "cli.agents.${AGENT_ID}.variant" "")
if [[ "$TARGET_CLI_TYPE" == "opencode" ]]; then
    sync_opencode_agent_frontmatter "$AGENT_ID" "$TARGET_MODEL" "$TARGET_VARIANT"
fi
TARGET_CMD=$(build_cli_command "$AGENT_ID")

log "Target: cli=${TARGET_CLI_TYPE}, model=${TARGET_MODEL}, cmd=${TARGET_CMD}"

# Step 3: 現在のCLIを /exit で終了
CURRENT_CLI=$(get_current_pane_cli "$PANE_TARGET")
log "Current CLI: ${CURRENT_CLI}"
send_exit "$PANE_TARGET" "$CURRENT_CLI"

# Step 4: シェルプロンプトを待つ
wait_for_shell_prompt "$PANE_TARGET"

# Step 5: 新しいCLIコマンドを送信
log "Launching new CLI: ${TARGET_CMD}"
tmux send-keys -t "$PANE_TARGET" "$TARGET_CMD" 2>/dev/null || true
sleep 0.3
tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true

# Step 6: tmux pane metadata 更新
DISPLAY_NAME=$(get_model_display_name "$AGENT_ID")
update_pane_metadata "$PANE_TARGET" "$TARGET_CLI_TYPE" "$DISPLAY_NAME"

log "=== CLI switch complete: ${AGENT_ID} → ${TARGET_CLI_TYPE}/${TARGET_MODEL} (${DISPLAY_NAME}) ==="
echo "OK: ${AGENT_ID} → ${TARGET_CLI_TYPE}/${TARGET_MODEL}"
