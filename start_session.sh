#!/usr/bin/env bash
# agent-orchestra v2 — start_session.sh
# Boots the multi-pane tmux orchestration: orchestrator + planner + tester + reviewer + engineer1..7.
#
# Usage:
#   ./start_session.sh                 # start all panes (preserve previous queue/dashboard state)
#   ./start_session.sh -c              # clean start (reset queue + dashboard)
#   ./start_session.sh -s              # setup tmux only (do not launch Claude)
#   ./start_session.sh -k              # "all-Opus" mode (every engineer pane runs Opus)
#   ./start_session.sh -t              # also open Windows Terminal tabs (WSL convenience)
#   ./start_session.sh -shell <bash|zsh>
#   ./start_session.sh --orchestrator-no-thinking
#   ./start_session.sh -S              # silent mode (suppress engineer completion echoes)
#   ./start_session.sh -h              # help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -----------------------------------------------------------------------------
# Configuration: language + shell defaults from config/settings.yaml
# -----------------------------------------------------------------------------
LANG_SETTING="ja"
if [ -f "./config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "ja")
fi

SHELL_SETTING="bash"
if [ -f "./config/settings.yaml" ]; then
    SHELL_SETTING=$(grep "^shell:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "bash")
fi

# -----------------------------------------------------------------------------
# Python venv preflight (inbox_watcher / inbox_write rely on .venv/bin/python3)
# -----------------------------------------------------------------------------
VENV_DIR="$SCRIPT_DIR/.venv"
if [ ! -f "$VENV_DIR/bin/python3" ] || ! "$VENV_DIR/bin/python3" -c "import yaml" 2>/dev/null; then
    echo -e "\033[1;33m[info]\033[0m Setting up Python venv..."
    if command -v python3 &>/dev/null; then
        python3 -m venv "$VENV_DIR" 2>/dev/null || {
            echo -e "\033[1;31m[error]\033[0m python3 -m venv failed. python3-venv may be required."
            echo "  Ubuntu/Debian: sudo apt-get install python3-venv"
            exit 1
        }
        if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
            "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" -q 2>/dev/null || {
                echo -e "\033[1;31m[error]\033[0m pip install failed."
                exit 1
            }
        fi
        echo -e "\033[1;32m[ok]\033[0m Python venv ready"
    else
        echo -e "\033[1;31m[error]\033[0m python3 not found. Run first_setup.sh first."
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Optional CLI adapter (multi-CLI support: claude / codex / copilot / kimi)
# -----------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/lib/cli_adapter.sh" ]; then
    source "$SCRIPT_DIR/lib/cli_adapter.sh"
    CLI_ADAPTER_LOADED=true
else
    CLI_ADAPTER_LOADED=false
fi

# -----------------------------------------------------------------------------
# Engineer roster — config-driven if available, else default 1..7
# -----------------------------------------------------------------------------
if [ "$CLI_ADAPTER_LOADED" = true ] && declare -F get_engineer_ids >/dev/null 2>&1; then
    _ENGINEER_IDS_STR=$(get_engineer_ids)
elif [ "$CLI_ADAPTER_LOADED" = true ] && declare -F get_ashigaru_ids >/dev/null 2>&1; then
    # Backwards compat: older cli_adapter.sh exposes get_ashigaru_ids
    _ENGINEER_IDS_STR=$(get_ashigaru_ids | sed 's/ashigaru/engineer/g')
else
    _ENGINEER_IDS_STR="engineer1 engineer2 engineer3 engineer4 engineer5 engineer6 engineer7"
fi
_ENGINEER_COUNT=$(echo "$_ENGINEER_IDS_STR" | wc -w | tr -d ' ')

log_info()    { echo -e "\033[1;33m[info]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[ok]\033[0m $1"; }
log_warn()    { echo -e "\033[1;31m[warn]\033[0m $1"; }

# -----------------------------------------------------------------------------
# generate_prompt — emit a PS1 string with role label colour (bash or zsh)
# -----------------------------------------------------------------------------
generate_prompt() {
    local label="$1"
    local color="$2"
    local shell_type="$3"

    if [ "$shell_type" = "zsh" ]; then
        echo "(%F{${color}}%B${label}%b%f) %F{green}%B%~%b%f%# "
    else
        local color_code
        case "$color" in
            red)     color_code="1;31" ;;
            green)   color_code="1;32" ;;
            yellow)  color_code="1;33" ;;
            blue)    color_code="1;34" ;;
            magenta) color_code="1;35" ;;
            cyan)    color_code="1;36" ;;
            *)       color_code="1;37" ;;
        esac
        echo "(\[\033[${color_code}m\]${label}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ "
    fi
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
SETUP_ONLY=false
OPEN_TERMINAL=false
CLEAN_MODE=false
ALL_OPUS_MODE=false
ORCHESTRATOR_NO_THINKING=false
SILENT_MODE=false
SHELL_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--setup-only)              SETUP_ONLY=true; shift ;;
        -c|--clean)                   CLEAN_MODE=true; shift ;;
        -k|--kessen|--all-opus)       ALL_OPUS_MODE=true; shift ;;
        -t|--terminal)                OPEN_TERMINAL=true; shift ;;
        --orchestrator-no-thinking)   ORCHESTRATOR_NO_THINKING=true; shift ;;
        -S|--silent)                  SILENT_MODE=true; shift ;;
        -shell|--shell)
            if [[ -n "$2" && "$2" != -* ]]; then
                SHELL_OVERRIDE="$2"; shift 2
            else
                echo "error: -shell requires bash or zsh"; exit 1
            fi
            ;;
        -h|--help)
            cat <<'HELP'

agent-orchestra v2 — start_session.sh

Usage: ./start_session.sh [options]

Options:
  -c, --clean                       Reset queue + dashboard (clean start)
  -k, --all-opus                    Run every engineer on Opus (default: Sonnet)
  -s, --setup-only                  Build tmux session but do not launch Claude
  -t, --terminal                    Also open Windows Terminal tabs (WSL)
  -shell, --shell <bash|zsh>        Override prompt shell (default from config/settings.yaml)
  -S, --silent                      Suppress engineer completion echoes (saves API cost)
  --orchestrator-no-thinking        Disable orchestrator extended thinking (relay-only)
  -h, --help                        Show this help

Roles & default models:
  orchestrator  Opus                # top-level dispatcher
  planner       Sonnet              # spec author / dispatcher
  tester        Sonnet              # blind QA (spec AC-based test execution)
  reviewer      Opus                # design + code review
  engineer1..7  Sonnet (Opus in --all-opus)

Sessions:
  orchestrator    1 pane  (orchestrator)
  multiagent 10 panes (planner + engineer1..7 + tester + reviewer in a 5x2 grid)

  5x2 pane layout:
     col0       col1        col2        col3       col4
     planner    engineer2   engineer4   engineer6  tester
     engineer1  engineer3   engineer5   engineer7  reviewer

Aliases (suggested):
  csst -> cd <repo> && ./start_session.sh
  css  -> tmux attach-session -t orchestrator
  csm  -> tmux attach-session -t multiagent

HELP
            exit 0
            ;;
        *)
            echo "unknown option: $1"
            echo "./start_session.sh -h for help"
            exit 1
            ;;
    esac
done

if [ -n "$SHELL_OVERRIDE" ]; then
    if [[ "$SHELL_OVERRIDE" == "bash" || "$SHELL_OVERRIDE" == "zsh" ]]; then
        SHELL_SETTING="$SHELL_OVERRIDE"
    else
        echo "error: -shell requires bash or zsh (got: $SHELL_OVERRIDE)"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------
clear
echo ""
echo -e "\033[1;36m=================================================================\033[0m"
echo -e "\033[1;37m  agent-orchestra v2 - starting session\033[0m"
echo -e "\033[1;36m=================================================================\033[0m"
echo "  orchestrator + planner + tester + reviewer + engineer1..${_ENGINEER_COUNT}"
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Tear down existing sessions
# -----------------------------------------------------------------------------
log_info "Tearing down existing tmux sessions..."
tmux kill-session -t multiagent 2>/dev/null && log_info "  multiagent: removed" || log_info "  multiagent: not present"
tmux kill-session -t orchestrator     2>/dev/null && log_info "  orchestrator:removed" || log_info "  orchestrator:not present"

# -----------------------------------------------------------------------------
# STEP 1.5: Backup dashboard + queue on --clean if non-empty
# -----------------------------------------------------------------------------
if [ "$CLEAN_MODE" = true ]; then
    BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
    NEED_BACKUP=false

    if [ -f "./dashboard.md" ] && grep -q "cmd_\|## In Progress\|## 進行中" "./dashboard.md" 2>/dev/null; then
        NEED_BACKUP=true
    fi
    if [ -f "./queue/outbox/orchestrator.yaml" ] && grep -q "id:" "./queue/outbox/orchestrator.yaml" 2>/dev/null; then
        NEED_BACKUP=true
    fi

    if [ "$NEED_BACKUP" = true ]; then
        mkdir -p "$BACKUP_DIR" || true
        cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/tasks"   "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/inbox"   "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/outbox"  "$BACKUP_DIR/" 2>/dev/null || true
        log_info "Backed up previous state to $BACKUP_DIR"
    fi
fi

# -----------------------------------------------------------------------------
# STEP 2: Ensure queue/ structure exists; reset on --clean
# -----------------------------------------------------------------------------
[ -d ./queue/reports ] || mkdir -p ./queue/reports
[ -d ./queue/tasks   ] || mkdir -p ./queue/tasks
[ -d ./queue/metrics ] || mkdir -p ./queue/metrics
[ -d ./queue/outbox  ] || mkdir -p ./queue/outbox

# inbox needs a Linux-FS symlink on WSL2 (inotifywait does not fire on /mnt/c/)
if [ "$(uname -s)" != "Darwin" ]; then
    INBOX_LINUX_DIR="$HOME/.local/share/agent-orchestra/inbox"
    if [ ! -L ./queue/inbox ]; then
        mkdir -p "$INBOX_LINUX_DIR"
        [ -d ./queue/inbox ] && cp ./queue/inbox/*.yaml "$INBOX_LINUX_DIR/" 2>/dev/null && rm -rf ./queue/inbox
        ln -sf "$INBOX_LINUX_DIR" ./queue/inbox
        log_info "  inbox -> Linux FS ($INBOX_LINUX_DIR) symlink created"
    fi
else
    [ -d ./queue/inbox ] || mkdir -p ./queue/inbox
fi

if [ "$CLEAN_MODE" = true ]; then
    log_info "Resetting queue files..."

    for i in $(seq 1 "$_ENGINEER_COUNT"); do
        cat > ./queue/tasks/engineer${i}.yaml << EOF
# engineer${i} task slot
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
    done

    cat > ./queue/tasks/reviewer.yaml << EOF
# reviewer task slot
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF

    cat > ./queue/tasks/tester.yaml << EOF
# tester task slot
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF

    for i in $(seq 1 "$_ENGINEER_COUNT"); do
        cat > ./queue/reports/engineer${i}_report.yaml << EOF
worker_id: engineer${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    done

    cat > ./queue/reports/reviewer_report.yaml << EOF
worker_id: reviewer
task_id: null
timestamp: ""
status: idle
result: null
EOF

    cat > ./queue/reports/tester_report.yaml << EOF
worker_id: tester
task_id: null
timestamp: ""
status: idle
result: null
EOF

    echo "inbox:" > ./queue/ntfy_inbox.yaml

    for role in orchestrator planner tester reviewer $_ENGINEER_IDS_STR; do
        echo "messages: []" > "./queue/inbox/${role}.yaml"
        echo "messages: []" > "./queue/outbox/${role}.yaml"
    done

    log_success "Queue reset complete"
else
    log_info "Preserving previous queue state"
fi

# -----------------------------------------------------------------------------
# STEP 3: Initialise dashboard on --clean
# -----------------------------------------------------------------------------
if [ "$CLEAN_MODE" = true ]; then
    log_info "Initialising dashboard..."
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

    if [ "$LANG_SETTING" = "ja" ]; then
        cat > ./dashboard.md << EOF
# Dashboard
最終更新: ${TIMESTAMP}

## 要対応 - user のご判断待ち
なし

## 進行中
なし

## 本日の完了
| 時刻 | エリア | タスク | 結果 |
|------|--------|--------|------|

## スキル化候補（承認待ち）
なし

## 生成済みスキル
なし

## 待機中
なし

## 質問
なし
EOF
    else
        cat > ./dashboard.md << EOF
# Dashboard
Last updated: ${TIMESTAMP}

## Action required (awaiting lord)
None

## In progress
None

## Today's completions
| Time | Area | Task | Result |
|------|------|------|--------|

## Skill candidates (pending approval)
None

## Generated skills
None

## On standby
None

## Questions
None
EOF
    fi

    log_success "  dashboard initialised (lang=$LANG_SETTING, shell=$SHELL_SETTING)"
else
    log_info "Preserving previous dashboard"
fi
echo ""

# -----------------------------------------------------------------------------
# STEP 4: tmux availability
# -----------------------------------------------------------------------------
if ! command -v tmux &> /dev/null; then
    echo ""
    echo "  [error] tmux not found"
    echo "  Run first_setup.sh first:"
    echo "      ./first_setup.sh"
    echo ""
    exit 1
fi

# -----------------------------------------------------------------------------
# STEP 5: Create orchestrator session (orchestrator pane)
# -----------------------------------------------------------------------------
log_info "Creating orchestrator session..."

if ! tmux has-session -t orchestrator 2>/dev/null; then
    tmux new-session -d -s orchestrator -n main
fi

tmux set-option -g window-size latest
tmux set-option -g aggressive-resize on

ORCH_PROMPT=$(generate_prompt "orchestrator" "magenta" "$SHELL_SETTING")
tmux send-keys -t orchestrator:main "cd \"$(pwd)\" && export PS1='${ORCH_PROMPT}' && clear" Enter
tmux select-pane -t orchestrator:main -P 'bg=#002b36'
tmux set-option -p -t orchestrator:main @agent_id "orchestrator"

log_success "  orchestrator pane ready"
echo ""

PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

# -----------------------------------------------------------------------------
# STEP 5.1: Create multiagent session - 10 panes (planner + engineer1..7 + tester + reviewer)
# 5x2 grid layout:
#   col0       col1        col2        col3       col4
#   planner    engineer2   engineer4   engineer6  tester
#   engineer1  engineer3   engineer5   engineer7  reviewer
# -----------------------------------------------------------------------------
log_info "Creating multi-agent session (planner + ${_ENGINEER_COUNT} engineers + tester + reviewer)..."

if ! tmux new-session -d -s multiagent -n "agents" -x 240 -y 60 2>/dev/null; then
    echo ""
    echo "  [error] failed to create tmux session 'multiagent'"
    echo "    Check: tmux ls"
    echo "    Kill:  tmux kill-session -t multiagent"
    echo ""
    exit 1
fi

# Force fixed window size so splits don't fail on small terminals
# (without this, detached sessions use 80x24 and splits collapse to 1-row panes)
tmux set-option -t multiagent window-size manual 2>/dev/null || true

# DISPLAY_MODE: shout (default) or silent (--silent)
if [ "$SILENT_MODE" = true ]; then
    tmux set-environment -t multiagent DISPLAY_MODE "silent"
    echo "  display mode: silent"
else
    tmux set-environment -t multiagent DISPLAY_MODE "shout"
fi

# 5x2 grid (10 panes) — deterministic split sequence
# Strategy: create 5 horizontal columns first (even-horizontal), then split each vertically.
# Working from rightmost column inwards keeps pane indices stable for the vertical splits.

# Step 1: create 5 columns by splitting pane 0 horizontally 4 times.
# After each split tmux makes the new (right) pane active, so always splitting pane 0
# yields a deterministic [pane0 | pane4 | pane3 | pane2 | pane1] layout.
for _ in 1 2 3 4; do
    tmux split-window -h -t "multiagent:agents.${PANE_BASE}"
done
tmux select-layout -t "multiagent:agents" even-horizontal

# Step 2: split each column vertically — RIGHT-TO-LEFT (col 4 first, col 0 last).
# Why reverse: tmux inserts new panes at `target+1` and renumbers higher-index panes.
# Splitting from the right keeps lower-index panes stable; the new pane gets the
# next free index. Final mapping (deterministic):
#   pane 0 = col0 top, pane 1 = col0 bot
#   pane 2 = col1 top, pane 3 = col1 bot
#   pane 4 = col2 top, pane 5 = col2 bot
#   pane 6 = col3 top, pane 7 = col3 bot
#   pane 8 = col4 top, pane 9 = col4 bot
for col in 4 3 2 1 0; do
    tmux split-window -v -t "multiagent:agents.$((PANE_BASE + col))"
done
tmux select-layout -t "multiagent:agents" tiled

# Pane labels / agent ids / colours - built dynamically
# Layout order: col0-top=planner, col0-bot=engineer1, col1-top=engineer2, col1-bot=engineer3,
#               col2-top=engineer4, col2-bot=engineer5, col3-top=engineer6, col3-bot=engineer7,
#               col4-top=tester, col4-bot=reviewer
PANE_LABELS=("planner")
AGENT_IDS=("planner")
PANE_COLORS=("red")
for _ai in $_ENGINEER_IDS_STR; do
    PANE_LABELS+=("$_ai")
    AGENT_IDS+=("$_ai")
    PANE_COLORS+=("blue")
done
PANE_LABELS+=("tester")
AGENT_IDS+=("tester")
PANE_COLORS+=("cyan")
PANE_LABELS+=("reviewer")
AGENT_IDS+=("reviewer")
PANE_COLORS+=("yellow")

# Default model labels (can be overridden by cli_adapter)
MODEL_NAMES=()
for _ai in "${AGENT_IDS[@]}"; do
    if [[ "$_ai" == "reviewer" ]]; then
        MODEL_NAMES+=("Opus")
    elif [[ "$_ai" == "planner" ]]; then
        MODEL_NAMES+=("Sonnet")
    elif [[ "$_ai" == "tester" ]]; then
        MODEL_NAMES+=("Sonnet")
    elif [ "$ALL_OPUS_MODE" = true ]; then
        MODEL_NAMES+=("Opus")
    else
        MODEL_NAMES+=("Sonnet")
    fi
done

if [ "$CLI_ADAPTER_LOADED" = true ] && declare -F get_model_display_name >/dev/null 2>&1; then
    for i in "${!AGENT_IDS[@]}"; do
        _agent="${AGENT_IDS[$i]}"
        MODEL_NAMES[$i]=$(get_model_display_name "$_agent")
    done
fi

for i in "${!AGENT_IDS[@]}"; do
    p=$((PANE_BASE + i))
    tmux select-pane -t "multiagent:agents.${p}" -T "${MODEL_NAMES[$i]}"
    tmux set-option -p -t "multiagent:agents.${p}" @agent_id "${AGENT_IDS[$i]}"
    tmux set-option -p -t "multiagent:agents.${p}" @model_name "${MODEL_NAMES[$i]}"
    tmux set-option -p -t "multiagent:agents.${p}" @current_task ""
    PROMPT_STR=$(generate_prompt "${PANE_LABELS[$i]}" "${PANE_COLORS[$i]}" "$SHELL_SETTING")
    tmux send-keys -t "multiagent:agents.${p}" "cd \"$(pwd)\" && export PS1='${PROMPT_STR}' && clear" Enter
done

tmux set-option -t multiagent -w pane-border-status top
tmux set-option -t multiagent -w pane-border-format '#{?pane_active,#[reverse],}#[bold]#{@agent_id}#[default] (#{@model_name}) #{@current_task}'

log_success "  planner / engineer / reviewer panes ready"
echo ""

# -----------------------------------------------------------------------------
# Helper: build CLI command (claude / cli_adapter)
# -----------------------------------------------------------------------------
_build_cmd() {
    local role="$1" default_model="$2"
    local cli_type="claude"
    local cmd="claude --model ${default_model} --effort max --dangerously-skip-permissions"
    if [ "$CLI_ADAPTER_LOADED" = true ]; then
        if declare -F get_cli_type >/dev/null 2>&1; then
            cli_type=$(get_cli_type "$role")
        fi
        if declare -F build_cli_command >/dev/null 2>&1; then
            cmd=$(build_cli_command "$role")
        fi
    fi
    if declare -F get_startup_prompt >/dev/null 2>&1; then
        local sp
        sp=$(get_startup_prompt "$role" 2>/dev/null)
        if [[ -n "$sp" ]]; then
            cmd="$cmd \"$sp\""
        fi
    fi
    echo "$cli_type|$cmd"
}

# -----------------------------------------------------------------------------
# STEP 6: Launch Claude (skipped on --setup-only)
# -----------------------------------------------------------------------------
if [ "$SETUP_ONLY" = false ]; then
    if [ "$CLI_ADAPTER_LOADED" = true ] && declare -F validate_cli_availability >/dev/null 2>&1; then
        _default_cli=$(get_cli_type "" 2>/dev/null || echo "claude")
        if ! validate_cli_availability "$_default_cli"; then
            exit 1
        fi
    elif ! command -v claude &> /dev/null; then
        log_warn "claude command not found"
        echo "  Re-run first_setup.sh:"
        echo "    ./first_setup.sh"
        exit 1
    fi

    rm -f /tmp/orchestrator_idle_* /tmp/shogun_idle_*
    echo "  cleared stale idle flags"

    log_info "Launching Claude in every pane..."

    # orchestrator
    if [ "$ORCHESTRATOR_NO_THINKING" = true ] && [ "$CLI_ADAPTER_LOADED" = true ]; then
        "$CLI_ADAPTER_PROJECT_ROOT/.venv/bin/python3" -c "
import yaml
f = '${CLI_ADAPTER_SETTINGS}'
with open(f) as fh: d = yaml.safe_load(fh) or {}
d.setdefault('cli',{}).setdefault('agents',{}).setdefault('orchestrator',{})['thinking'] = False
with open(f,'w') as fh: yaml.safe_dump(d, fh, default_flow_style=False, allow_unicode=True, sort_keys=False)
" 2>/dev/null || true
        log_info "  orchestrator settings.yaml: thinking=false"
    fi
    IFS='|' read -r _orch_cli _orch_cmd <<< "$(_build_cmd orchestrator opus)"
    tmux set-option -p -t "orchestrator:main" @agent_cli "$_orch_cli"
    tmux send-keys -t orchestrator:main "$_orch_cmd"
    tmux send-keys -t orchestrator:main Enter
    if declare -F get_model_display_name >/dev/null 2>&1; then
        _orch_display=$(get_model_display_name "orchestrator" 2>/dev/null || echo "Opus")
        tmux set-option -p -t "orchestrator:main" @model_name "$_orch_display" 2>/dev/null || true
    fi
    log_info "  orchestrator launched ($_orch_cli)"

    sleep 1

    # planner (pane 0 of multiagent)
    PLANNER_PANE=$((PANE_BASE + 0))
    IFS='|' read -r _pl_cli _pl_cmd <<< "$(_build_cmd planner sonnet)"
    tmux set-option -p -t "multiagent:agents.${PLANNER_PANE}" @agent_cli "$_pl_cli"
    tmux send-keys -t "multiagent:agents.${PLANNER_PANE}" "$_pl_cmd"
    tmux send-keys -t "multiagent:agents.${PLANNER_PANE}" Enter
    log_info "  planner launched ($_pl_cli)"

    # engineers (panes 1..N)
    ENGINEER_PANES=()
    for i in $(seq 1 "$_ENGINEER_COUNT"); do
        p=$((PANE_BASE + i))
        ENGINEER_PANES+=("$p")
        if [ "$ALL_OPUS_MODE" = true ]; then
            _eng_default="opus"
        else
            _eng_default="sonnet"
        fi
        IFS='|' read -r _eng_cli _eng_cmd <<< "$(_build_cmd "engineer${i}" "$_eng_default")"
        tmux set-option -p -t "multiagent:agents.${p}" @agent_cli "$_eng_cli"
        tmux send-keys -t "multiagent:agents.${p}" "$_eng_cmd"
        tmux send-keys -t "multiagent:agents.${p}" Enter
    done
    if [ "$ALL_OPUS_MODE" = true ]; then
        log_info "  engineer1..${_ENGINEER_COUNT} launched (all-Opus)"
    else
        log_info "  engineer1..${_ENGINEER_COUNT} launched (Sonnet)"
    fi

    # tester (second-to-last pane, index = planner(0) + engineers(1..N) + tester(N+1))
    TESTER_PANE=$((PANE_BASE + _ENGINEER_COUNT + 1))
    IFS='|' read -r _ts_cli _ts_cmd <<< "$(_build_cmd tester sonnet)"
    tmux set-option -p -t "multiagent:agents.${TESTER_PANE}" @agent_cli "$_ts_cli"
    tmux send-keys -t "multiagent:agents.${TESTER_PANE}" "$_ts_cmd"
    tmux send-keys -t "multiagent:agents.${TESTER_PANE}" Enter
    log_info "  tester launched ($_ts_cli)"

    # reviewer (last pane, index = planner(0) + engineers(1..N) + tester(N+1) + reviewer(N+2))
    REVIEWER_PANE=$((PANE_BASE + _ENGINEER_COUNT + 2))
    IFS='|' read -r _rv_cli _rv_cmd <<< "$(_build_cmd reviewer opus)"
    tmux set-option -p -t "multiagent:agents.${REVIEWER_PANE}" @agent_cli "$_rv_cli"
    tmux send-keys -t "multiagent:agents.${REVIEWER_PANE}" "$_rv_cmd"
    tmux send-keys -t "multiagent:agents.${REVIEWER_PANE}" Enter
    log_info "  reviewer launched ($_rv_cli)"

    if [ "$ALL_OPUS_MODE" = true ]; then
        log_success "Session up: all-Opus mode (orchestrator + reviewer + every engineer = Opus)"
    else
        log_success "Session up: planner=Sonnet, tester=Sonnet, engineer*=Sonnet, orchestrator=reviewer=Opus"
    fi
    echo ""

    # -------------------------------------------------------------------------
    # STEP 6.5: Each pane self-loads its .claude/rules/<role>.md via session-start
    # -------------------------------------------------------------------------
    log_info "Each pane self-loads .claude/rules/<role>.md via SessionStart hook"
    echo ""

    echo "  Waiting for orchestrator Claude bootstrap (up to 30s)..."
    for i in {1..30}; do
        if tmux capture-pane -t orchestrator:main -p | grep -q "bypass permissions"; then
            echo "  orchestrator ready (${i}s)"
            break
        fi
        sleep 1
    done

    # -------------------------------------------------------------------------
    # STEP 6.6: Start inbox_watcher for every role
    # -------------------------------------------------------------------------
    log_info "Starting inbox watchers..."

    mkdir -p "$SCRIPT_DIR/logs"
    for role in orchestrator planner tester reviewer $_ENGINEER_IDS_STR; do
        [ -f "$SCRIPT_DIR/queue/inbox/${role}.yaml" ] || echo "messages: []" > "$SCRIPT_DIR/queue/inbox/${role}.yaml"
    done

    pkill -f "inbox_watcher.sh" 2>/dev/null || true
    pkill -f "inotifywait.*queue/inbox" 2>/dev/null || true
    pkill -f "fswatch.*queue/inbox" 2>/dev/null || true
    sleep 1

    # orchestrator
    _orch_watcher_cli=$(tmux show-options -p -t "orchestrator:main" -v @agent_cli 2>/dev/null || echo "claude")
    nohup env ASW_DISABLE_ESCALATION=1 ASW_PROCESS_TIMEOUT=0 ASW_DISABLE_NORMAL_NUDGE=0 \
        bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" orchestrator "orchestrator:main" "$_orch_watcher_cli" \
        >> "$SCRIPT_DIR/logs/inbox_watcher_orchestrator.log" 2>&1 &
    disown

    # planner
    _pl_watcher_cli=$(tmux show-options -p -t "multiagent:agents.${PLANNER_PANE}" -v @agent_cli 2>/dev/null || echo "claude")
    nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" planner "multiagent:agents.${PLANNER_PANE}" "$_pl_watcher_cli" \
        >> "$SCRIPT_DIR/logs/inbox_watcher_planner.log" 2>&1 &
    disown

    # engineers
    for i in $(seq 1 "$_ENGINEER_COUNT"); do
        p=$((PANE_BASE + i))
        _eng_watcher_cli=$(tmux show-options -p -t "multiagent:agents.${p}" -v @agent_cli 2>/dev/null || echo "claude")
        nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" "engineer${i}" "multiagent:agents.${p}" "$_eng_watcher_cli" \
            >> "$SCRIPT_DIR/logs/inbox_watcher_engineer${i}.log" 2>&1 &
        disown
    done

    # tester
    _ts_watcher_cli=$(tmux show-options -p -t "multiagent:agents.${TESTER_PANE}" -v @agent_cli 2>/dev/null || echo "claude")
    nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" "tester" "multiagent:agents.${TESTER_PANE}" "$_ts_watcher_cli" \
        >> "$SCRIPT_DIR/logs/inbox_watcher_tester.log" 2>&1 &
    disown

    # reviewer
    _rv_watcher_cli=$(tmux show-options -p -t "multiagent:agents.${REVIEWER_PANE}" -v @agent_cli 2>/dev/null || echo "claude")
    nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" "reviewer" "multiagent:agents.${REVIEWER_PANE}" "$_rv_watcher_cli" \
        >> "$SCRIPT_DIR/logs/inbox_watcher_reviewer.log" 2>&1 &
    disown

    log_success "  $((_ENGINEER_COUNT + 4)) inbox watchers running (orchestrator + planner + engineer*${_ENGINEER_COUNT} + tester + reviewer)"
    echo ""
fi

# -----------------------------------------------------------------------------
# STEP 6.7: Archive ntfy_inbox entries older than 7 days
# -----------------------------------------------------------------------------
if [ -f ./queue/ntfy_inbox.yaml ]; then
    _archive_result=$(python3 -c "
import yaml, sys
from datetime import datetime, timedelta, timezone

INBOX = './queue/ntfy_inbox.yaml'
ARCHIVE = './queue/ntfy_inbox_archive.yaml'
DAYS = 7

with open(INBOX) as f:
    data = yaml.safe_load(f) or {}

entries = data.get('inbox', []) or []
if not entries:
    sys.exit(0)

cutoff = datetime.now(timezone(timedelta(hours=9))) - timedelta(days=DAYS)
recent, old = [], []

for e in entries:
    ts = e.get('timestamp', '')
    try:
        dt = datetime.fromisoformat(str(ts))
        if dt < cutoff and e.get('status') == 'processed':
            old.append(e)
        else:
            recent.append(e)
    except Exception:
        recent.append(e)

if not old:
    sys.exit(0)

try:
    with open(ARCHIVE) as f:
        archive = yaml.safe_load(f) or {}
except FileNotFoundError:
    archive = {}
archive_entries = archive.get('inbox', []) or []
archive_entries.extend(old)
with open(ARCHIVE, 'w') as f:
    yaml.dump({'inbox': archive_entries}, f, allow_unicode=True, default_flow_style=False)

with open(INBOX, 'w') as f:
    yaml.dump({'inbox': recent}, f, allow_unicode=True, default_flow_style=False)

print(f'archived {len(old)}, kept {len(recent)}')
" 2>/dev/null) || true
    if [ -n "$_archive_result" ]; then
        log_info "ntfy_inbox archive: $_archive_result -> ntfy_inbox_archive.yaml"
    fi
fi

# -----------------------------------------------------------------------------
# STEP 6.8: ntfy listener (if configured)
# -----------------------------------------------------------------------------
NTFY_TOPIC=$(grep 'ntfy_topic:' ./config/settings.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')
if [ -n "$NTFY_TOPIC" ]; then
    pkill -f "ntfy_listener.sh" 2>/dev/null || true
    [ ! -f ./queue/ntfy_inbox.yaml ] && echo "inbox:" > ./queue/ntfy_inbox.yaml
    nohup bash "$SCRIPT_DIR/scripts/ntfy_listener.sh" &>/dev/null &
    disown
    log_info "ntfy listener started (topic: $NTFY_TOPIC)"
else
    log_info "ntfy not configured; listener skipped"
fi
echo ""

# -----------------------------------------------------------------------------
# STEP 7: Summary
# -----------------------------------------------------------------------------
log_info "Session summary:"
echo ""
echo "  tmux sessions"
tmux list-sessions | sed 's/^/      /'
echo ""
echo "  Pane layout:"
echo ""
echo "      [orchestrator]  orchestrator"
echo "      [multiagent]    5x2 grid:"
echo "                       planner    engineer2   engineer4   engineer6  tester"
echo "                       engineer1  engineer3   engineer5   engineer7  reviewer"
echo ""

if [ "$SETUP_ONLY" = true ]; then
    echo "  --setup-only: Claude was NOT launched."
    echo ""
    echo "  Manual launch:"
    echo "      tmux send-keys -t orchestrator:main 'claude --dangerously-skip-permissions' Enter"
    echo "      for p in \$(seq $PANE_BASE $((PANE_BASE+9))); do"
    echo "          tmux send-keys -t multiagent:agents.\$p 'claude --dangerously-skip-permissions' Enter"
    echo "      done"
    echo ""
fi

echo "  Next steps:"
echo "      attach orchestrator:   tmux attach-session -t orchestrator       (alias: css)"
echo "      attach multiagent:     tmux attach-session -t multiagent   (alias: csm)"
echo ""
echo "  Each pane auto-loads .claude/rules/<role>.md via the session-start hook."
echo ""

# -----------------------------------------------------------------------------
# STEP 8: Windows Terminal tabs (-t)
# -----------------------------------------------------------------------------
if [ "$OPEN_TERMINAL" = true ]; then
    log_info "Opening Windows Terminal tabs..."
    if command -v wt.exe &> /dev/null; then
        wt.exe -w 0 new-tab wsl.exe -e bash -c "tmux attach-session -t orchestrator" \; new-tab wsl.exe -e bash -c "tmux attach-session -t multiagent"
        log_success "  terminal tabs opened"
    else
        log_warn "  wt.exe not found; attach manually"
    fi
    echo ""
fi
