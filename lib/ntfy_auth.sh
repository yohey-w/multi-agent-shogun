#!/usr/bin/env bash
# ntfy_auth.sh — ntfy認証ヘルパーライブラリ
# FR-066: ntfy認証対応
#
# 提供関数:
#   ntfy_get_auth_args [auth_env_file]  → curl認証フラグを出力
#   ntfy_validate_topic [topic]         → 0=OK, 1=弱いトピック名
#
# 認証方式:
#   - token: Bearer token (自己ホスト ntfy用)
#   - basic: ユーザー名+パスワード (自己ホスト ntfy用)
#   - none: 認証なし (公開ntfy.sh、後方互換)
#
# 設定ファイル: config/ntfy_auth.env (git非追跡)

# --- ntfy_get_auth_args ---
# curl用の認証引数を標準出力に返す
# 引数: [auth_env_file] — 認証設定ファイルのパス（省略時はconfig/ntfy_auth.env）
# 出力: curl引数文字列 (例: "-H" "Authorization: Bearer tk_xxx")
#        認証設定なしの場合は空文字列（後方互換）
ntfy_get_auth_args() {
    local auth_file="${1:-}"

    # auth_fileが未指定の場合、スクリプト位置からの相対パスで解決
    if [ -z "$auth_file" ]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || true
        auth_file="${script_dir}/config/ntfy_auth.env"
    fi

    # 環境変数を読み込み（ファイルが存在する場合のみ）
    if [ -f "$auth_file" ]; then
        # shellcheck disable=SC1090
        source "$auth_file"
    fi

    # Bearer token認証（優先）
    if [ -n "${NTFY_TOKEN:-}" ]; then
        printf '%s\n' "-H" "Authorization: Bearer ${NTFY_TOKEN}"
        return 0
    fi

    # Basic認証（フォールバック）
    if [ -n "${NTFY_USER:-}" ] && [ -n "${NTFY_PASS:-}" ]; then
        printf '%s\n' "-u" "${NTFY_USER}:${NTFY_PASS}"
        return 0
    fi

    # 認証なし（後方互換: 公開ntfy.shではこちら）
    return 0
}

# --- ntfy_validate_topic ---
# トピック名のセキュリティ強度を検証
# 引数: topic — トピック名
# 戻り値: 0=OK(十分な長さ+ランダム性), 1=弱い(短すぎる or 推測可能)
# 標準エラー: 警告メッセージ
ntfy_validate_topic() {
    local topic="${1:-}"

    # 空チェック
    if [ -z "$topic" ]; then
        echo "ERROR: ntfy topic is empty" >&2
        return 1
    fi

    # 長さチェック（8文字未満は危険）
    if [ "${#topic}" -lt 8 ]; then
        echo "WARNING: ntfy topic '$topic' is too short (${#topic} chars). Recommend 12+ chars for security." >&2
        return 1
    fi

    # 一般的な弱いトピック名チェック
    local weak_topics="test mytopic notifications alerts messages my-topic default ntfy"
    local lower_topic
    lower_topic=$(echo "$topic" | tr '[:upper:]' '[:lower:]')
    for weak in $weak_topics; do
        if [ "$lower_topic" = "$weak" ]; then
            echo "WARNING: ntfy topic '$topic' is a commonly used name. Use a random string." >&2
            return 1
        fi
    done

    return 0
}
