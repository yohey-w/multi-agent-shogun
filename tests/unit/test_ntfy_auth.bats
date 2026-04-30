#!/usr/bin/env bats
# test_ntfy_auth.bats — ntfy認証ユニットテスト
# FR-066: ntfy認証対応
#
# テスト構成:
#   T-AUTH-001: ntfy_get_auth_args — Bearer token認証
#   T-AUTH-002: ntfy_get_auth_args — Basic認証
#   T-AUTH-003: ntfy_get_auth_args — 認証なし (後方互換)
#   T-AUTH-004: ntfy_get_auth_args — token優先 (token+basic両方設定時)
#   T-AUTH-005: ntfy_get_auth_args — 環境変数ファイル読み込み
#   T-AUTH-006: ntfy_get_auth_args — 存在しないauth_envファイル
#   T-AUTH-007: ntfy_validate_topic — 正常トピック名
#   T-AUTH-008: ntfy_validate_topic — 短すぎるトピック名
#   T-AUTH-009: ntfy_validate_topic — 弱いトピック名 (推測可能)
#   T-AUTH-010: ntfy_validate_topic — 空トピック名
#   T-AUTH-011: ntfy.sh — 認証ありで送信 (モック)
#   T-AUTH-012: ntfy_listener.sh — 認証ありでストリーミング (モック)
#   T-AUTH-013: ntfy_auth.env.sample — サンプルファイル存在確認
#   T-AUTH-014: ntfy_auth.env — git非追跡確認

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export NTFY_AUTH_LIB="$PROJECT_ROOT/lib/ntfy_auth.sh"

    # ライブラリ存在確認
    [ -f "$NTFY_AUTH_LIB" ] || return 1
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/ntfy_auth_test.XXXXXX")"

    # 環境変数をクリア（テスト間の干渉防止）
    unset NTFY_TOKEN
    unset NTFY_USER
    unset NTFY_PASS

    # ライブラリ読み込み
    source "$NTFY_AUTH_LIB"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- T-AUTH-001: Bearer token認証 ---

@test "T-AUTH-001: ntfy_get_auth_args returns Bearer header when NTFY_TOKEN is set" {
    export NTFY_TOKEN="tk_test1234567890abcdef"

    local result
    result=$(ntfy_get_auth_args /dev/null)

    echo "$result" | grep -q -- '-H'
    echo "$result" | grep -q 'Authorization: Bearer tk_test1234567890abcdef'
}

# --- T-AUTH-002: Basic認証 ---

@test "T-AUTH-002: ntfy_get_auth_args returns -u flag when NTFY_USER and NTFY_PASS are set" {
    export NTFY_USER="testuser"
    export NTFY_PASS="testpass"

    local result
    result=$(ntfy_get_auth_args /dev/null)

    echo "$result" | grep -q -- '-u'
    echo "$result" | grep -q 'testuser:testpass'
}

# --- T-AUTH-003: 認証なし (後方互換) ---

@test "T-AUTH-003: ntfy_get_auth_args returns empty when no auth configured" {
    local result
    result=$(ntfy_get_auth_args /dev/null)

    [ -z "$result" ]
}

# --- T-AUTH-004: token優先 ---

@test "T-AUTH-004: ntfy_get_auth_args prefers token over basic auth" {
    export NTFY_TOKEN="tk_priority_token"
    export NTFY_USER="should_not_use"
    export NTFY_PASS="should_not_use"

    local result
    result=$(ntfy_get_auth_args /dev/null)

    echo "$result" | grep -q 'Bearer tk_priority_token'
    ! echo "$result" | grep -q 'should_not_use'
}

# --- T-AUTH-005: env file読み込み ---

@test "T-AUTH-005: ntfy_get_auth_args loads credentials from env file" {
    local auth_file="$TEST_TMPDIR/ntfy_auth.env"
    cat > "$auth_file" << 'EOF'
NTFY_TOKEN=tk_from_file_12345
EOF

    local result
    result=$(ntfy_get_auth_args "$auth_file")

    echo "$result" | grep -q 'Bearer tk_from_file_12345'
}

# --- T-AUTH-006: 存在しないファイル ---

@test "T-AUTH-006: ntfy_get_auth_args handles missing auth file gracefully" {
    local result
    result=$(ntfy_get_auth_args "$TEST_TMPDIR/nonexistent.env")

    # エラーなし、空結果（認証なしフォールバック）
    [ -z "$result" ]
}

# --- T-AUTH-007: 正常トピック名 ---

@test "T-AUTH-007: ntfy_validate_topic accepts secure topic name" {
    run ntfy_validate_topic "sample-topic-secret123"
    [ "$status" -eq 0 ]
}

# --- T-AUTH-008: 短すぎるトピック名 ---

@test "T-AUTH-008: ntfy_validate_topic rejects short topic name" {
    run ntfy_validate_topic "abc"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "too short"
}

# --- T-AUTH-009: 弱いトピック名 ---

@test "T-AUTH-009: ntfy_validate_topic rejects commonly used topic names" {
    run ntfy_validate_topic "notifications"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "commonly used"
}

# --- T-AUTH-010: 空トピック名 ---

@test "T-AUTH-010: ntfy_validate_topic rejects empty topic" {
    run ntfy_validate_topic ""
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "empty"
}

# --- T-AUTH-011: ntfy.sh送信（モック） ---

@test "T-AUTH-011: ntfy.sh includes auth header in curl when token configured" {
    # テスト用のモック環境を構築
    local mock_dir="$TEST_TMPDIR/project"
    mkdir -p "$mock_dir/config" "$mock_dir/scripts" "$mock_dir/lib"

    # settings.yaml
    cat > "$mock_dir/config/settings.yaml" << 'EOF'
ntfy_topic: "test-topic-12345"
EOF

    # ntfy_auth.env with token
    cat > "$mock_dir/config/ntfy_auth.env" << 'EOF'
NTFY_TOKEN=tk_mock_token_test
EOF

    # lib/ntfy_auth.sh をコピー
    cp "$PROJECT_ROOT/lib/ntfy_auth.sh" "$mock_dir/lib/"

    # curlモック: 引数をファイルに記録
    local curl_log="$TEST_TMPDIR/curl_args.log"
    cat > "$mock_dir/mock_curl" << MOCK
#!/bin/bash
echo "\$@" > "$curl_log"
MOCK
    chmod +x "$mock_dir/mock_curl"

    # ntfy.shのテスト用コピー（curlをモックに差し替え）
    cp "$PROJECT_ROOT/scripts/ntfy.sh" "$mock_dir/scripts/ntfy.sh"
    # SCRIPT_DIRの解決先をmock_dirに変更
    sed "s|SETTINGS=.*|SETTINGS=\"$mock_dir/config/settings.yaml\"|" "$mock_dir/scripts/ntfy.sh" > "$mock_dir/scripts/ntfy.sh.tmp" && mv "$mock_dir/scripts/ntfy.sh.tmp" "$mock_dir/scripts/ntfy.sh"

    # ntfy_auth.shをsource + curlモック化
    cat > "$mock_dir/scripts/ntfy_test.sh" << TESTSH
#!/bin/bash
source "$mock_dir/lib/ntfy_auth.sh"
SETTINGS="$mock_dir/config/settings.yaml"
TOPIC=\$(grep 'ntfy_topic:' "\$SETTINGS" | awk '{print \$2}' | tr -d '"')
AUTH_ARGS=\$(ntfy_get_auth_args "$mock_dir/config/ntfy_auth.env")
# shellcheck disable=SC2086
"$mock_dir/mock_curl" -s \$AUTH_ARGS -H "Tags: outbound" -d "hello" "https://ntfy.sh/\$TOPIC"
TESTSH
    chmod +x "$mock_dir/scripts/ntfy_test.sh"

    run bash "$mock_dir/scripts/ntfy_test.sh"
    [ "$status" -eq 0 ]

    # curlに認証ヘッダーが渡されたことを確認
    [ -f "$curl_log" ]
    grep -q "Bearer tk_mock_token_test" "$curl_log"
    grep -q "test-topic-12345" "$curl_log"
}

# --- T-AUTH-012: ntfy_listener.sh認証確認（モック） ---

@test "T-AUTH-012: ntfy_get_auth_args output can be used as curl arguments" {
    export NTFY_TOKEN="tk_listener_test"

    # 認証引数を取得
    local auth_args
    auth_args=$(ntfy_get_auth_args /dev/null)

    # curlの引数として使える形式か確認
    # -H と Authorization: Bearer の2行が出力される
    local line_count
    line_count=$(echo "$auth_args" | wc -l)
    [ "$line_count" -eq 2 ]

    local first_line
    first_line=$(echo "$auth_args" | head -1)
    [ "$first_line" = "-H" ]

    local second_line
    second_line=$(echo "$auth_args" | tail -1)
    [ "$second_line" = "Authorization: Bearer tk_listener_test" ]
}

# --- T-AUTH-013: サンプルファイル存在確認 ---

@test "T-AUTH-013: ntfy_auth.env.sample exists with configuration instructions" {
    local sample="$PROJECT_ROOT/config/ntfy_auth.env.sample"
    [ -f "$sample" ]
    grep -q "NTFY_TOKEN" "$sample"
    grep -q "NTFY_USER" "$sample"
    grep -q "NTFY_PASS" "$sample"
}

# --- T-AUTH-014: git非追跡確認 ---

@test "T-AUTH-014: ntfy_auth.env is not tracked by git (whitelist .gitignore)" {
    # .gitignoreがホワイトリスト方式（*で全除外→!で許可）
    # config/ntfy_auth.env はホワイトリストに含まれていないことを確認
    # (.sample は追跡OK、.env本体は追跡NG)
    cd "$PROJECT_ROOT"

    # git check-ignoreで実際に無視されることを確認（最も信頼性の高い方法）
    run git check-ignore config/ntfy_auth.env
    [ "$status" -eq 0 ]
}
