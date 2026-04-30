#!/usr/bin/env bash
# capture_local.sh — 複数パスから最新N枚のスクショを探索・取得
# Usage: capture_local.sh [-n NUM] [-p PATH]
# パスを指定しない場合、config/settings.yaml の screenshot.paths を優先順に探索

set -euo pipefail

NUM=1
SCREENSHOT_PATH=""

# --- 引数解析 ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n) NUM="$2"; shift 2 ;;
        -p) SCREENSHOT_PATH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [-n NUM] [-p PATH]"
            echo "  -n NUM   取得する枚数（デフォルト: 1）"
            echo "  -p PATH  スクショフォルダのパス（省略時はconfig/settings.yamlから全パス探索）"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# settings.yaml を探索: カレントディレクトリ → リポジトリルート
if [[ -f "config/settings.yaml" ]]; then
    SETTINGS_FILE="config/settings.yaml"
elif [[ -n "${MULTI_AGENT_SHOGUN_DIR:-}" && -f "${MULTI_AGENT_SHOGUN_DIR}/config/settings.yaml" ]]; then
    SETTINGS_FILE="${MULTI_AGENT_SHOGUN_DIR}/config/settings.yaml"
else
    # git root から探索
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    if [[ -n "$GIT_ROOT" && -f "$GIT_ROOT/config/settings.yaml" ]]; then
        SETTINGS_FILE="$GIT_ROOT/config/settings.yaml"
    else
        SETTINGS_FILE=""
    fi
fi

# --- 単一パス指定の場合 ---
if [[ -n "$SCREENSHOT_PATH" ]]; then
    if [[ ! -d "$SCREENSHOT_PATH" ]]; then
        echo "ERROR: スクショフォルダが見つかりません: $SCREENSHOT_PATH" >&2
        exit 1
    fi
    find "$SCREENSHOT_PATH" -maxdepth 1 \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn \
        | head -n "$NUM" \
        | cut -d' ' -f2-
    exit 0
fi

# --- 複数パス探索（settings.yaml の screenshot.paths） ---
PATHS=()

if [[ -n "$SETTINGS_FILE" && -f "$SETTINGS_FILE" ]]; then
    # paths: 配列を読み取り（YAML簡易パース）
    in_paths=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*paths: ]]; then
            in_paths=true
            continue
        fi
        if $in_paths; then
            # インデント付きの - "..." 行を読む
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\"(.+)\" ]]; then
                PATHS+=("${BASH_REMATCH[1]}")
            elif [[ "$line" =~ ^[[:space:]]*- ]]; then
                # クォートなし
                val=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
                PATHS+=("$val")
            else
                # 配列終了
                break
            fi
        fi
    done < "$SETTINGS_FILE"
fi

# paths が空ならエラー
if [[ ${#PATHS[@]} -eq 0 ]]; then
    echo "ERROR: config/settings.yaml に screenshot.paths が設定されていません。" >&2
    echo "設定例:" >&2
    echo '  screenshot:' >&2
    echo '    paths:' >&2
    echo '      - "/path/to/your/Screenshots/"' >&2
    exit 1
fi

# --- 全パスから画像を収集し、最新N枚を返す ---
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

found_any=false
for dir in "${PATHS[@]}"; do
    if [[ -d "$dir" ]]; then
        find "$dir" -maxdepth 1 \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -printf '%T@ %p\n' 2>/dev/null >> "$TMPFILE"
        found_any=true
    fi
done

if ! $found_any; then
    echo "ERROR: 有効なスクショフォルダが見つかりません。探索パス:" >&2
    for dir in "${PATHS[@]}"; do
        echo "  - $dir ($([ -d "$dir" ] && echo '存在' || echo '不在'))" >&2
    done
    exit 1
fi

# 全パスの画像を更新日時でソートし最新N枚を出力
sort -rn "$TMPFILE" | head -n "$NUM" | cut -d' ' -f2-
