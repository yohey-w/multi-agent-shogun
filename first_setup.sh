#!/usr/bin/env bash
# ============================================================
# first_setup.sh - multi-agent-shogun 初回セットアップスクリプト
# Ubuntu / WSL / Mac 用環境構築ツール
# ============================================================
# 実行方法:
#   chmod +x first_setup.sh
#   ./first_setup.sh
# ============================================================

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# アイコン付きログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}\n"
}

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 結果追跡用変数
RESULTS=()
HAS_ERROR=false

echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║  🏯 multi-agent-shogun インストーラー                         ║"
echo "  ║     Initial Setup Script for Ubuntu / WSL                    ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  このスクリプトは初回セットアップ用です。"
echo "  依存関係の確認とディレクトリ構造の作成を行います。"
echo ""
echo "  インストール先: $SCRIPT_DIR"
echo ""

# ============================================================
# STEP 1: OS チェック
# ============================================================
log_step "STEP 1: システム環境チェック"

# OS情報を取得
UNAME_S="$(uname -s)"
if [ "$UNAME_S" = "Darwin" ]; then
    OS_NAME="macOS"
    OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
    log_info "OS: $OS_NAME $OS_VERSION"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_VERSION=$VERSION_ID
    log_info "OS: $OS_NAME $OS_VERSION"
else
    OS_NAME="Unknown"
    log_warn "OS情報を取得できませんでした"
fi

# WSL チェック
IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
    log_info "環境: WSL (Windows Subsystem for Linux)"
    IS_WSL=true
elif [ "$UNAME_S" = "Darwin" ]; then
    log_info "環境: macOS"
else
    log_info "環境: Native Linux"
fi

RESULTS+=("システム環境: OK")

# ============================================================
# STEP 2: tmux チェック・インストール
# ============================================================
log_step "STEP 2: tmux チェック"

if command -v tmux &> /dev/null; then
    TMUX_VERSION=$(tmux -V | awk '{print $2}')
    log_success "tmux がインストール済みです (v$TMUX_VERSION)"
    RESULTS+=("tmux: OK (v$TMUX_VERSION)")
else
    log_warn "tmux がインストールされていません"
    echo ""

    # Ubuntu/Debian系かチェック
    if command -v apt-get &> /dev/null; then
        log_info "tmux をインストール中..."
        if ! sudo -n apt-get update -qq 2>/dev/null; then
            if ! sudo apt-get update -qq 2>/dev/null; then
                log_error "sudo の実行に失敗しました。ターミナルから直接実行してください"
                RESULTS+=("tmux: インストール失敗 (sudo失敗)")
                HAS_ERROR=true
            fi
        fi

        if [ "$HAS_ERROR" != true ]; then
            if ! sudo -n apt-get install -y tmux 2>/dev/null; then
                if ! sudo apt-get install -y tmux 2>/dev/null; then
                    log_error "tmux のインストールに失敗しました"
                    RESULTS+=("tmux: インストール失敗")
                    HAS_ERROR=true
                fi
            fi
        fi

        if command -v tmux &> /dev/null; then
            TMUX_VERSION=$(tmux -V | awk '{print $2}')
            log_success "tmux インストール完了 (v$TMUX_VERSION)"
            RESULTS+=("tmux: インストール完了 (v$TMUX_VERSION)")
        else
            log_error "tmux のインストールに失敗しました"
            RESULTS+=("tmux: インストール失敗")
            HAS_ERROR=true
        fi
    else
        log_error "apt-get が見つかりません。手動で tmux をインストールしてください"
        echo ""
        echo "  インストール方法:"
        echo "    Ubuntu/Debian: sudo apt-get install tmux"
        echo "    Fedora:        sudo dnf install tmux"
        echo "    macOS:         brew install tmux"
        RESULTS+=("tmux: 未インストール (手動インストール必要)")
        HAS_ERROR=true
    fi
fi

# ============================================================
# STEP 3: tmux マウススクロール設定
# ============================================================
log_step "STEP 3: tmux マウススクロール設定"

TMUX_CONF="$HOME/.tmux.conf"
TMUX_MOUSE_SETTING="set -g mouse on"

if [ -f "$TMUX_CONF" ] && grep -qF "$TMUX_MOUSE_SETTING" "$TMUX_CONF" 2>/dev/null; then
    log_info "tmux マウス設定は既に ~/.tmux.conf に存在します"
else
    log_info "~/.tmux.conf に '$TMUX_MOUSE_SETTING' を追加中..."
    echo "" >> "$TMUX_CONF"
    echo "# マウススクロール有効化 (added by first_setup.sh)" >> "$TMUX_CONF"
    echo "$TMUX_MOUSE_SETTING" >> "$TMUX_CONF"
    log_success "tmux マウス設定を追加しました"
fi

# tmux が起動中の場合は即反映
if command -v tmux &> /dev/null && tmux list-sessions &> /dev/null; then
    log_info "tmux が起動中のため、設定を即反映します..."
    if tmux source-file "$TMUX_CONF" 2>/dev/null; then
        log_success "tmux 設定を再読み込みしました"
    else
        log_warn "tmux 設定の再読み込みに失敗しました（手動で tmux source-file ~/.tmux.conf を実行してください）"
    fi
else
    log_info "tmux は起動していないため、次回起動時に反映されます"
fi

RESULTS+=("tmux マウス設定: OK")

# ============================================================
# STEP 4: Node.js チェック
# ============================================================
log_step "STEP 4: Node.js チェック"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    log_success "Node.js がインストール済みです ($NODE_VERSION)"

    # バージョンチェック（18以上推奨）
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | tr -d 'v')
    if [ "$NODE_MAJOR" -lt 18 ]; then
        log_warn "Node.js 18以上を推奨します（現在: $NODE_VERSION）"
        RESULTS+=("Node.js: OK (v$NODE_MAJOR - 要アップグレード推奨)")
    else
        RESULTS+=("Node.js: OK ($NODE_VERSION)")
    fi
else
    log_warn "Node.js がインストールされていません"
    echo ""

    # nvm が既にインストール済みか確認
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        log_info "nvm が既にインストール済みです。Node.js をセットアップ中..."
        \. "$NVM_DIR/nvm.sh"
    else
        # nvm 自動インストール
        log_info "nvm をインストール中..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    # nvm が利用可能なら Node.js をインストール
    if command -v nvm &> /dev/null; then
        log_info "Node.js 20 をインストール中..."
        nvm install 20 || true
        nvm use 20 || true

        if command -v node &> /dev/null; then
            NODE_VERSION=$(node -v)
            log_success "Node.js インストール完了 ($NODE_VERSION)"
            RESULTS+=("Node.js: インストール完了 ($NODE_VERSION)")
        else
            log_error "Node.js のインストールに失敗しました"
            RESULTS+=("Node.js: インストール失敗")
            HAS_ERROR=true
        fi
    elif [ "$HAS_ERROR" != true ]; then
        log_error "nvm のインストールに失敗しました"
        echo ""
        echo "  手動でインストールしてください:"
        echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
        echo "    source ~/.bashrc"
        echo "    nvm install 20"
        echo ""
        RESULTS+=("Node.js: 未インストール (nvm失敗)")
        HAS_ERROR=true
    fi
fi

# npm チェック
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    log_success "npm がインストール済みです (v$NPM_VERSION)"
else
    if command -v node &> /dev/null; then
        log_warn "npm が見つかりません（Node.js と一緒にインストールされるはずです）"
    fi
fi

# ============================================================
# STEP 4.5: Python3 / venv / flock / file-watcher チェック
# ============================================================
log_step "STEP 4.5: Python3 / venv / flock / file-watcher チェック"

# Detect OS
SETUP_OS="$(uname -s)"

# --- python3 ---
if command -v python3 &> /dev/null; then
    PY3_VERSION=$(python3 --version 2>&1)
    log_success "python3 がインストール済みです ($PY3_VERSION)"
    RESULTS+=("python3: OK ($PY3_VERSION)")
else
    log_warn "python3 がインストールされていません"
    if command -v apt-get &> /dev/null; then
        log_info "python3 をインストール中..."
        sudo apt-get update -qq 2>/dev/null
        if sudo apt-get install -y python3 2>/dev/null; then
            PY3_VERSION=$(python3 --version 2>&1)
            log_success "python3 インストール完了 ($PY3_VERSION)"
            RESULTS+=("python3: インストール完了 ($PY3_VERSION)")
        else
            log_error "python3 のインストールに失敗しました"
            RESULTS+=("python3: インストール失敗")
            HAS_ERROR=true
        fi
    elif [ "$SETUP_OS" = "Darwin" ]; then
        log_error "python3 がインストールされていません"
        echo "  macOS: brew install python3 または https://www.python.org/ からインストール"
        RESULTS+=("python3: 未インストール (手動インストール必要)")
        HAS_ERROR=true
    else
        log_error "手動で python3 をインストールしてください"
        RESULTS+=("python3: 未インストール (手動インストール必要)")
        HAS_ERROR=true
    fi
fi

# --- Python venv + PyYAML (via requirements.txt) ---
VENV_DIR="$SCRIPT_DIR/.venv"
if [ -f "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import yaml" 2>/dev/null; then
    log_success "Python venv + PyYAML がセットアップ済みです"
    RESULTS+=("venv + PyYAML: OK")
else
    log_info "Python venv をセットアップ中..."
    if command -v python3 &> /dev/null; then
        if python3 -m venv "$VENV_DIR" 2>/dev/null; then
            log_success "venv 作成完了: $VENV_DIR"
            if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
                if "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null; then
                    log_success "PyYAML インストール完了 (venv)"
                    RESULTS+=("venv + PyYAML: セットアップ完了")
                else
                    log_error "pip install に失敗しました"
                    RESULTS+=("venv + PyYAML: pip失敗")
                    HAS_ERROR=true
                fi
            else
                log_warn "requirements.txt が見つかりません"
                RESULTS+=("venv + PyYAML: requirements.txt不在")
                HAS_ERROR=true
            fi
        else
            log_error "python3 -m venv に失敗しました"
            echo "  python3-venv パッケージが必要かもしれません:"
            echo "    Ubuntu/Debian: sudo apt-get install python3-venv"
            RESULTS+=("venv: 作成失敗")
            HAS_ERROR=true
        fi
    else
        log_error "python3 が必要です（上のステップでインストールしてください）"
        RESULTS+=("venv: python3不在のためスキップ")
        HAS_ERROR=true
    fi
fi

# --- flock ---
if command -v flock &> /dev/null; then
    log_success "flock がインストール済みです"
    RESULTS+=("flock: OK")
else
    log_warn "flock がインストールされていません"
    if [ "$SETUP_OS" = "Darwin" ]; then
        echo "  macOS: brew install flock"
        RESULTS+=("flock: 未インストール (brew install flock)")
    elif command -v apt-get &> /dev/null; then
        log_info "util-linux (flock含む) は通常プリインストールです"
        echo "  sudo apt-get install util-linux"
        RESULTS+=("flock: 未インストール (apt-get install util-linux)")
    else
        echo "  手動でインストールしてください"
        RESULTS+=("flock: 未インストール")
    fi
    HAS_ERROR=true
fi

# --- Bash version check (macOS ships with bash 3.2) ---
if [ "$SETUP_OS" = "Darwin" ]; then
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log_warn "bash 3.2 detected (macOS default)."
        log_warn "This tool requires bash 4.0+."
        log_warn "Install: brew install bash"
        log_warn "Then reopen terminal and retry."
        HAS_ERROR=true
    else
        log_success "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]} detected"
    fi
fi

# --- coreutils (recommended for macOS) ---
if [ "$SETUP_OS" = "Darwin" ]; then
    if ! command -v gtimeout &>/dev/null; then
        log_warn "GNU coreutils not found. inbox_watcher will use bash fallback for timeout."
        log_warn "Recommended: brew install coreutils"
        RESULTS+=("coreutils: 未インストール (brew install coreutils)")
    else
        log_success "GNU coreutils detected (gtimeout available)"
    fi
fi

# --- File watcher (inotifywait / fswatch) ---
if [ "$SETUP_OS" = "Darwin" ]; then
    # macOS: fswatch
    if command -v fswatch &> /dev/null; then
        log_success "fswatch がインストール済みです (macOS file watcher)"
        RESULTS+=("file-watcher: OK (fswatch)")
    else
        log_warn "fswatch がインストールされていません"
        echo "  macOS: brew install fswatch"
        RESULTS+=("file-watcher: 未インストール (brew install fswatch)")
        HAS_ERROR=true
    fi
else
    # Linux: inotifywait
    if command -v inotifywait &> /dev/null; then
        log_success "inotify-tools がインストール済みです"
        RESULTS+=("file-watcher: OK (inotifywait)")
    else
        log_warn "inotify-tools がインストールされていません"
        if command -v apt-get &> /dev/null; then
            log_info "inotify-tools をインストール中..."
            if sudo apt-get install -y inotify-tools 2>/dev/null; then
                log_success "inotify-tools インストール完了"
                RESULTS+=("file-watcher: インストール完了 (inotifywait)")
            else
                log_error "inotify-tools のインストールに失敗しました"
                RESULTS+=("file-watcher: インストール失敗")
                HAS_ERROR=true
            fi
        else
            log_error "手動で inotify-tools をインストールしてください"
            RESULTS+=("file-watcher: 未インストール")
            HAS_ERROR=true
        fi
    fi
fi

# ============================================================
# STEP 5: Claude Code CLI チェック（ネイティブ版）
# ※ npm版は公式非推奨（deprecated）。ネイティブ版を使用する。
#    Node.jsはMCPサーバー（npx経由）で引き続き必要。
# ============================================================
log_step "STEP 5: Claude Code CLI チェック"

# ネイティブ版の既存インストールを検出するため、PATHに ~/.local/bin を含める
export PATH="$HOME/.local/bin:$PATH"

NEED_CLAUDE_INSTALL=false
HAS_NPM_CLAUDE=false

if command -v claude &> /dev/null; then
    # claude コマンドは存在する → 実際に動くかチェック
    CLAUDE_VERSION=$(claude --version 2>&1)
    CLAUDE_PATH=$(which claude 2>/dev/null)

    if [ $? -eq 0 ] && [ "$CLAUDE_VERSION" != "unknown" ] && [[ "$CLAUDE_VERSION" != *"not found"* ]]; then
        # 動作する claude が見つかった → npm版かネイティブ版かを判定
        if echo "$CLAUDE_PATH" | grep -qi "npm\|node_modules\|AppData"; then
            # npm版が動いている
            HAS_NPM_CLAUDE=true
            log_warn "npm版 Claude Code CLI が検出されました（公式非推奨）"
            log_info "検出パス: $CLAUDE_PATH"
            log_info "バージョン: $CLAUDE_VERSION"
            echo ""
            echo "  npm版は公式で非推奨（deprecated）となっています。"
            echo "  ネイティブ版をインストールし、npm版はアンインストールすることを推奨します。"
            echo ""
            if [ ! -t 0 ]; then
                REPLY="Y"
            else
                read -p "  ネイティブ版をインストールしますか? [Y/n]: " REPLY
            fi
            REPLY=${REPLY:-Y}
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                NEED_CLAUDE_INSTALL=true
                # npm版のアンインストール案内
                echo ""
                log_info "先にnpm版をアンインストールしてください:"
                if echo "$CLAUDE_PATH" | grep -qi "mnt/c\|AppData"; then
                    echo "  Windows の PowerShell で:"
                    echo "    npm uninstall -g @anthropic-ai/claude-code"
                else
                    echo "    npm uninstall -g @anthropic-ai/claude-code"
                fi
                echo ""
            else
                log_warn "ネイティブ版への移行をスキップしました（npm版で続行）"
                RESULTS+=("Claude Code CLI: OK (npm版・移行推奨)")
            fi
        else
            # ネイティブ版が正常に動作している
            log_success "Claude Code CLI がインストール済みです（ネイティブ版）"
            log_info "バージョン: $CLAUDE_VERSION"
            RESULTS+=("Claude Code CLI: OK")
        fi
    else
        # command -v で見つかるが動かない（npm版でNode.js無し等）
        log_warn "Claude Code CLI が見つかりましたが正常に動作しません"
        log_info "検出パス: $CLAUDE_PATH"
        if echo "$CLAUDE_PATH" | grep -qi "npm\|node_modules\|AppData"; then
            HAS_NPM_CLAUDE=true
            log_info "→ npm版（Node.js依存）が検出されました"
        else
            log_info "→ バージョン取得に失敗しました"
        fi
        NEED_CLAUDE_INSTALL=true
    fi
else
    # claude コマンドが見つからない
    NEED_CLAUDE_INSTALL=true
fi

if [ "$NEED_CLAUDE_INSTALL" = true ]; then
    log_info "ネイティブ版 Claude Code CLI をインストールします"
    log_info "Claude Code CLI をインストール中（ネイティブ版）..."
    curl -fsSL https://claude.ai/install.sh | bash

    # PATHを更新（インストール直後は反映されていない可能性）
    export PATH="$HOME/.local/bin:$PATH"

    # .bashrc に永続化（重複追加を防止）
    if ! grep -q 'export PATH="\$HOME/.local/bin:\$PATH"' "$HOME/.bashrc" 2>/dev/null; then
        echo '' >> "$HOME/.bashrc"
        echo '# Claude Code CLI PATH (added by first_setup.sh)' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        log_info "~/.local/bin を ~/.bashrc の PATH に追加しました"
    fi

    if command -v claude &> /dev/null; then
        CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
        log_success "Claude Code CLI インストール完了（ネイティブ版）"
        log_info "バージョン: $CLAUDE_VERSION"
        RESULTS+=("Claude Code CLI: インストール完了")

        # npm版が残っている場合の案内
        if [ "$HAS_NPM_CLAUDE" = true ]; then
            echo ""
            log_info "ネイティブ版がPATHで優先されるため、npm版は無効化されます"
            log_info "npm版を完全に削除するには以下を実行してください:"
            if echo "$CLAUDE_PATH" | grep -qi "mnt/c\|AppData"; then
                echo "  Windows の PowerShell で:"
                echo "    npm uninstall -g @anthropic-ai/claude-code"
            else
                echo "    npm uninstall -g @anthropic-ai/claude-code"
            fi
        fi
    else
        log_error "インストールに失敗しました。パスを確認してください"
        log_info "~/.local/bin がPATHに含まれているか確認してください"
        RESULTS+=("Claude Code CLI: インストール失敗")
        HAS_ERROR=true
    fi
fi

# ============================================================
# STEP 6: ディレクトリ構造作成
# ============================================================
log_step "STEP 6: ディレクトリ構造作成"

# 必要なディレクトリ一覧
DIRECTORIES=(
    "queue/tasks"
    "queue/reports"
    "config"
    "status"
    "instructions"
    "logs"
    "demo_output"
    "skills"
    "memory"
)

CREATED_COUNT=0
EXISTED_COUNT=0

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$SCRIPT_DIR/$dir" ]; then
        mkdir -p "$SCRIPT_DIR/$dir"
        log_info "作成: $dir/"
        CREATED_COUNT=$((CREATED_COUNT + 1))
    else
        EXISTED_COUNT=$((EXISTED_COUNT + 1))
    fi
done

if [ $CREATED_COUNT -gt 0 ]; then
    log_success "$CREATED_COUNT 個のディレクトリを作成しました"
fi
if [ $EXISTED_COUNT -gt 0 ]; then
    log_info "$EXISTED_COUNT 個のディレクトリは既に存在します"
fi

RESULTS+=("ディレクトリ構造: OK (作成:$CREATED_COUNT, 既存:$EXISTED_COUNT)")

# ============================================================
# STEP 7: 設定ファイル初期化
# ============================================================
log_step "STEP 7: 設定ファイル確認"

# config/settings.yaml
if [ ! -f "$SCRIPT_DIR/config/settings.yaml" ]; then
    log_info "config/settings.yaml を作成中..."
    cat > "$SCRIPT_DIR/config/settings.yaml" << EOF
# multi-agent-shogun 設定ファイル

# 言語設定
# ja: 日本語（戦国風日本語のみ、併記なし）
# en: 英語（戦国風日本語 + 英訳併記）
# その他の言語コード（es, zh, ko, fr, de 等）も対応
language: ja

# シェル設定
# bash: bash用プロンプト（デフォルト）
# zsh: zsh用プロンプト
shell: bash

# スキル設定
skill:
  # スキル保存先（スキル名に shogun- プレフィックスを付けて保存）
  save_path: "~/.claude/skills/"

  # ローカルスキル保存先（このプロジェクト専用）
  local_path: "$SCRIPT_DIR/skills/"

# ログ設定
logging:
  level: info  # debug | info | warn | error
  path: "$SCRIPT_DIR/logs/"
EOF
    log_success "settings.yaml を作成しました"
else
    log_info "config/settings.yaml は既に存在します"
fi

# config/projects.yaml
if [ ! -f "$SCRIPT_DIR/config/projects.yaml" ]; then
    log_info "config/projects.yaml を作成中..."
    cat > "$SCRIPT_DIR/config/projects.yaml" << 'EOF'
projects:
  - id: sample_project
    name: "Sample Project"
    path: "/path/to/your/project"
    priority: high
    status: active

current_project: sample_project
EOF
    log_success "projects.yaml を作成しました"
else
    log_info "config/projects.yaml は既に存在します"
fi

# memory/global_context.md（システム全体のコンテキスト）
if [ ! -f "$SCRIPT_DIR/memory/global_context.md" ]; then
    log_info "memory/global_context.md を作成中..."
    cat > "$SCRIPT_DIR/memory/global_context.md" << 'EOF'
# グローバルコンテキスト
最終更新: (未設定)

## システム方針
- (殿の好み・方針をここに記載)

## プロジェクト横断の決定事項
- (複数プロジェクトに影響する決定をここに記載)

## 注意事項
- (全エージェントが知るべき注意点をここに記載)
EOF
    log_success "global_context.md を作成しました"
else
    log_info "memory/global_context.md は既に存在します"
fi

RESULTS+=("設定ファイル: OK")

# ============================================================
# STEP 8: 足軽用タスク・レポートファイル初期化
# ============================================================
log_step "STEP 8: キューファイル初期化"

# 足軽数を settings.yaml から動的に取得（設定がなければデフォルト7）
_SETUP_VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python3"
_SETUP_ASHIGARU_COUNT=$(
    if [[ -x "$_SETUP_VENV_PYTHON" ]]; then
        "$_SETUP_VENV_PYTHON" -c "
import yaml
try:
    with open('$SCRIPT_DIR/config/settings.yaml') as f:
        cfg = yaml.safe_load(f) or {}
    agents = cfg.get('cli', {}).get('agents', {})
    count = len([k for k in agents if k.startswith('ashigaru')])
    print(count if count > 0 else 7)
except Exception:
    print(7)
" 2>/dev/null
    else
        echo 7
    fi
)
_SETUP_ASHIGARU_COUNT=${_SETUP_ASHIGARU_COUNT:-7}

# 足軽用タスクファイル作成
for i in $(seq 1 "$_SETUP_ASHIGARU_COUNT"); do
    TASK_FILE="$SCRIPT_DIR/queue/tasks/ashigaru${i}.yaml"
    if [ ! -f "$TASK_FILE" ]; then
        cat > "$TASK_FILE" << EOF
# 足軽${i}専用タスクファイル
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
    fi
done
log_info "足軽タスクファイル (1-${_SETUP_ASHIGARU_COUNT}) を確認/作成しました"

# 足軽用レポートファイル作成
for i in $(seq 1 "$_SETUP_ASHIGARU_COUNT"); do
    REPORT_FILE="$SCRIPT_DIR/queue/reports/ashigaru${i}_report.yaml"
    if [ ! -f "$REPORT_FILE" ]; then
        cat > "$REPORT_FILE" << EOF
worker_id: ashigaru${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    fi
done
log_info "足軽レポートファイル (1-${_SETUP_ASHIGARU_COUNT}) を確認/作成しました"

RESULTS+=("キューファイル: OK")

# ============================================================
# STEP 9: スクリプト実行権限付与
# ============================================================
log_step "STEP 9: 実行権限設定"

SCRIPTS=(
    "setup.sh"
    "shutsujin_departure.sh"
    "first_setup.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        chmod +x "$SCRIPT_DIR/$script"
        log_info "$script に実行権限を付与しました"
    fi
done

RESULTS+=("実行権限: OK")

# ============================================================
# STEP 10: bashrc alias設定
# ============================================================
log_step "STEP 10: alias設定"

# alias追加対象ファイル
BASHRC_FILE="$HOME/.bashrc"

# css/csm を関数として定義（destroy-unattached で自動掃除）
# - 複数端末から接続しても画面サイズが干渉しない
# - SSH切断・アプリ終了時に一時セッションが自動消滅
# - 本体セッション (shogun/multiagent) は絶対に消えない
CSS_FUNC='css() { local s="shogun-$$"; local cols=$(tput cols 2>/dev/null || echo 80); tmux new-session -d -t shogun -s "$s" 2>/dev/null && tmux set-option -t "$s" destroy-unattached on 2>/dev/null; if [ "$cols" -lt 80 ]; then tmux new-window -t "$s" -n mobile 2>/dev/null; tmux attach-session -t "$s:mobile" 2>/dev/null || tmux attach-session -t shogun; else tmux attach-session -t "$s" 2>/dev/null || tmux attach-session -t shogun; fi; }'
CSM_FUNC='csm() { local s="multi-$$"; local cols=$(tput cols 2>/dev/null || echo 80); tmux new-session -d -t multiagent -s "$s" 2>/dev/null && tmux set-option -t "$s" destroy-unattached on 2>/dev/null; if [ "$cols" -lt 80 ]; then tmux new-window -t "$s" -n mobile 2>/dev/null; tmux attach-session -t "$s:mobile" 2>/dev/null || tmux attach-session -t multiagent; else tmux attach-session -t "$s" 2>/dev/null || tmux attach-session -t multiagent; fi; }'

ALIAS_ADDED=false

if [ -f "$BASHRC_FILE" ]; then
    # 古い alias 形式を削除（存在する場合）
    if grep -q "alias css=" "$BASHRC_FILE" 2>/dev/null; then
        sed -i '/alias css=/d' "$BASHRC_FILE"
        log_info "旧 alias css を削除しました"
    fi
    if grep -q "alias csm=" "$BASHRC_FILE" 2>/dev/null; then
        sed -i '/alias csm=/d' "$BASHRC_FILE"
        log_info "旧 alias csm を削除しました"
    fi

    # css 関数
    if ! grep -q "^css()" "$BASHRC_FILE" 2>/dev/null; then
        if ! grep -q "multi-agent-shogun aliases" "$BASHRC_FILE" 2>/dev/null; then
            echo "" >> "$BASHRC_FILE"
            echo "# multi-agent-shogun aliases (added by first_setup.sh)" >> "$BASHRC_FILE"
        fi
        echo "$CSS_FUNC" >> "$BASHRC_FILE"
        log_info "css 関数を追加しました（将軍ウィンドウ — 自動掃除付き）"
        ALIAS_ADDED=true
    else
        # 関数は存在する → 最新版に更新
        sed -i '/^css()/d' "$BASHRC_FILE"
        echo "$CSS_FUNC" >> "$BASHRC_FILE"
        log_info "css 関数を更新しました"
        ALIAS_ADDED=true
    fi

    # csm 関数
    if ! grep -q "^csm()" "$BASHRC_FILE" 2>/dev/null; then
        echo "$CSM_FUNC" >> "$BASHRC_FILE"
        log_info "csm 関数を追加しました（家老・足軽ウィンドウ — 自動掃除付き）"
        ALIAS_ADDED=true
    else
        sed -i '/^csm()/d' "$BASHRC_FILE"
        echo "$CSM_FUNC" >> "$BASHRC_FILE"
        log_info "csm 関数を更新しました"
        ALIAS_ADDED=true
    fi
else
    log_warn "$BASHRC_FILE が見つかりません"
fi

if [ "$ALIAS_ADDED" = true ]; then
    log_success "alias設定を追加しました（destroy-unattached 方式）"
    log_warn "alias を反映するには、以下のいずれかを実行してください："
    log_info "  1. source ~/.bashrc"
    log_info "  2. PowerShell で 'wsl --shutdown' してからターミナルを開き直す"
    log_info "  ※ ウィンドウを閉じるだけでは WSL が終了しないため反映されません"
fi

RESULTS+=("alias設定: OK")

# ============================================================
# STEP 10.5: WSL メモリ最適化設定
# ============================================================
if [ "$IS_WSL" = true ]; then
    log_step "STEP 10.5: WSL メモリ最適化設定"

    # .wslconfig の確認・設定（Windows側のユーザーディレクトリに配置）
    WIN_USER_DIR=$(cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
    if [ -n "$WIN_USER_DIR" ]; then
        # Windows パスを WSL パスに変換
        WSLCONFIG_PATH=$(wslpath "$WIN_USER_DIR")/.wslconfig

        if [ -f "$WSLCONFIG_PATH" ]; then
            if grep -q "autoMemoryReclaim" "$WSLCONFIG_PATH" 2>/dev/null; then
                log_info ".wslconfig に autoMemoryReclaim は既に設定済みです"
            else
                log_info ".wslconfig に autoMemoryReclaim=gradual を追加中..."
                # [experimental] セクションがあるか確認
                if grep -q "\[experimental\]" "$WSLCONFIG_PATH" 2>/dev/null; then
                    # [experimental] セクションの直後に追加
                    sed -i '/\[experimental\]/a autoMemoryReclaim=gradual' "$WSLCONFIG_PATH"
                else
                    echo "" >> "$WSLCONFIG_PATH"
                    echo "[experimental]" >> "$WSLCONFIG_PATH"
                    echo "autoMemoryReclaim=gradual" >> "$WSLCONFIG_PATH"
                fi
                log_success ".wslconfig に autoMemoryReclaim=gradual を追加しました"
                log_warn "反映には 'wsl --shutdown' 後の再起動が必要です"
            fi
        else
            log_info ".wslconfig を新規作成中..."
            cat > "$WSLCONFIG_PATH" << 'EOF'
[experimental]
autoMemoryReclaim=gradual
EOF
            log_success ".wslconfig を作成しました (autoMemoryReclaim=gradual)"
            log_warn "反映には 'wsl --shutdown' 後の再起動が必要です"
        fi

        RESULTS+=("WSL メモリ最適化: OK (.wslconfig設定済み)")
    else
        log_warn "Windowsユーザーディレクトリの取得に失敗しました"
        log_info "手動で %USERPROFILE%\\.wslconfig に以下を追加してください:"
        echo "  [experimental]"
        echo "  autoMemoryReclaim=gradual"
        RESULTS+=("WSL メモリ最適化: 手動設定必要")
    fi

    # 即時キャッシュクリアの案内
    log_info "メモリキャッシュを即時クリアするには以下を実行:"
    echo "  sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'"
else
    log_info "WSL環境ではないため、メモリ最適化設定をスキップ"
fi

# ============================================================
# STEP 11: Memory MCP セットアップ
# ============================================================
log_step "STEP 11: Memory MCP セットアップ"

if command -v claude &> /dev/null; then
    # Memory MCP が既に設定済みか確認
    if claude mcp list 2>/dev/null | grep -q "memory"; then
        log_info "Memory MCP は既に設定済みです"
        RESULTS+=("Memory MCP: OK (設定済み)")
    else
        log_info "Memory MCP を設定中..."
        if claude mcp add memory \
            -e MEMORY_FILE_PATH="$SCRIPT_DIR/memory/shogun_memory.jsonl" \
            -- npx -y @modelcontextprotocol/server-memory 2>/dev/null; then
            log_success "Memory MCP 設定完了"
            RESULTS+=("Memory MCP: 設定完了")
        else
            log_warn "Memory MCP の設定に失敗しました（手動で設定可能）"
            RESULTS+=("Memory MCP: 設定失敗 (手動設定可能)")
        fi
    fi
else
    log_warn "claude コマンドが見つからないため Memory MCP 設定をスキップ"
    RESULTS+=("Memory MCP: スキップ (claude未インストール)")
fi

# ============================================================
# 結果サマリー
# ============================================================
echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║  📋 セットアップ結果サマリー                                  ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""

for result in "${RESULTS[@]}"; do
    if [[ $result == *"未インストール"* ]] || [[ $result == *"失敗"* ]]; then
        echo -e "  ${RED}✗${NC} $result"
    elif [[ $result == *"アップグレード"* ]] || [[ $result == *"スキップ"* ]]; then
        echo -e "  ${YELLOW}!${NC} $result"
    else
        echo -e "  ${GREEN}✓${NC} $result"
    fi
done

echo ""

if [ "$HAS_ERROR" = true ]; then
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║  ⚠️  一部の依存関係が不足しています                           ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  上記の警告を確認し、不足しているものをインストールしてください。"
    echo "  すべての依存関係が揃ったら、再度このスクリプトを実行して確認できます。"
else
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║  ✅ セットアップ完了！準備万端でござる！                      ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
fi

echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  📜 次のステップ                                             │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "  ⚠️  初回のみ: 以下を手動で実行してください"
echo ""
echo "  STEP 0: PATHの反映（このシェルにインストール結果を反映）"
echo "     source ~/.bashrc"
echo ""
echo "  STEP A: OAuth認証 + Bypass Permissions の承認（1コマンドで完了）"
echo "     claude --dangerously-skip-permissions"
echo ""
echo "     1. ブラウザが開く → Anthropicアカウントでログイン → CLIに戻る"
echo "        ※ WSLでブラウザが開かない場合は、表示されるURLをWindows側の"
echo "          ブラウザに手動で貼り付けてください"
echo "     2. Bypass Permissions の承認画面が表示される"
echo "        → 「Yes, I accept」を選択（↓キーで2を選んでEnter）"
echo "     3. /exit で退出"
echo ""
echo "     ※ 一度承認すれば ~/.claude/ に保存され、以降は不要です"
echo ""
echo "  ────────────────────────────────────────────────────────────────"
echo ""
echo "  出陣（全エージェント起動）:"
echo "     ./shutsujin_departure.sh"
echo ""
echo "  オプション:"
echo "     ./shutsujin_departure.sh -s            # セットアップのみ（Claude手動起動）"
echo "     ./shutsujin_departure.sh -t            # Windows Terminalタブ展開"
echo "     ./shutsujin_departure.sh -shell bash   # bash用プロンプトで起動"
echo "     ./shutsujin_departure.sh -shell zsh    # zsh用プロンプトで起動"
echo ""
echo "  ※ シェル設定は config/settings.yaml の shell: でも変更可能です"
echo ""
echo "  詳細は README.md を参照してください。"
echo ""
echo "  ════════════════════════════════════════════════════════════════"
echo "   天下布武！ (Tenka Fubu!)"
echo "  ════════════════════════════════════════════════════════════════"
echo ""

# 依存関係不足の場合は exit 1 を返す（install.bat が検知できるように）
if [ "$HAS_ERROR" = true ]; then
    exit 1
fi