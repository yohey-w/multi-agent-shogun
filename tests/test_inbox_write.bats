#!/usr/bin/env bats
# test_inbox_write.bats — inbox_write.sh ユニットテスト
# リグレッションテスト仕様書 T-001 ~ T-012 実装
#
# テスト構成:
#   T-001~T-002: 引数バリデーション
#   T-003~T-004: 正常書き込み（新規/追記）
#   T-005: メッセージID一意性
#   T-006~T-007: デフォルト値（type/from）
#   T-008~T-009: Overflow Protection（50件制限）
#   T-010: flock競合時のリトライ
#   T-011: 特殊文字のエスケープ処理
#   T-012: inbox初期化（ディレクトリ自動作成）

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export INBOX_WRITE_SCRIPT="$PROJECT_ROOT/scripts/inbox_write.sh"
    export VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python3"

    # スクリプト存在確認（前提条件）
    [ -f "$INBOX_WRITE_SCRIPT" ] || return 1

    # venv python3 + PyYAML存在確認
    "$VENV_PYTHON" -c "import yaml" 2>/dev/null || return 1
}

setup() {
    # テスト毎に独立したtmpディレクトリを作成
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/inbox_write_test.XXXXXX")"
    export TEST_INBOX_DIR="$TEST_TMPDIR/queue/inbox"
    mkdir -p "$TEST_INBOX_DIR"

    # inbox_write.shが参照するSCRIPT_DIRをtmpに向けるため、wrapper scriptを作成
    # inbox_write.shはSCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"で解決するため、
    # シンボリックリンクでテスト用ディレクトリを作成
    export TEST_SCRIPT_DIR="$TEST_TMPDIR/scripts"
    mkdir -p "$TEST_SCRIPT_DIR"

    # 元のスクリプトをコピー（SCRIPT_DIRをテスト用に書き換える）
    sed "s|SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE\[0\]}\")/..*|SCRIPT_DIR=\"$TEST_TMPDIR\"|" \
        "$PROJECT_ROOT/scripts/inbox_write.sh" > "$TEST_SCRIPT_DIR/inbox_write.sh"
    chmod +x "$TEST_SCRIPT_DIR/inbox_write.sh"

    # .venvをプロジェクトルートからシンボリックリンク（inbox_write.shが$SCRIPT_DIR/.venv/bin/python3を参照）
    ln -sf "$PROJECT_ROOT/.venv" "$TEST_TMPDIR/.venv"

    export TEST_INBOX_WRITE="$TEST_SCRIPT_DIR/inbox_write.sh"
}

teardown() {
    # テスト用tmpディレクトリを削除
    [ -n "$TEST_TMPDIR" ] && [ -d "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# T-001: 引数バリデーション — target未指定でexit 1
# =============================================================================

@test "T-001: no arguments → exit 1 with Usage message" {
    run bash "$TEST_INBOX_WRITE"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}

# =============================================================================
# T-002: 引数バリデーション — content未指定でexit 1
# =============================================================================

@test "T-002: only target, no content → exit 1" {
    run bash "$TEST_INBOX_WRITE" "test_agent"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}

# =============================================================================
# T-003: 正常書き込み — 新規inboxファイル作成
# =============================================================================

@test "T-003: normal write to new inbox file → messages array with correct fields" {
    run bash "$TEST_INBOX_WRITE" "test_agent" "テストメッセージ" "cmd_new" "shogun"
    [ "$status" -eq 0 ]

    # YAMLファイルが作成されていることを確認
    [ -f "$TEST_INBOX_DIR/test_agent.yaml" ]

    # python3でYAML検証
    "$VENV_PYTHON" <<EOF
import yaml, sys

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

# messages配列が存在し、1件あること
assert 'messages' in data, 'messages key not found'
assert len(data['messages']) == 1, f'Expected 1 message, got {len(data["messages"])}'

msg = data['messages'][0]

# 必須フィールドの存在確認
required_fields = ['id', 'from', 'timestamp', 'type', 'content', 'read']
for field in required_fields:
    assert field in msg, f'Field {field} not found in message'

# フィールド値の検証
assert msg['from'] == 'shogun', f'Expected from=shogun, got {msg["from"]}'
assert msg['type'] == 'cmd_new', f'Expected type=cmd_new, got {msg["type"]}'
assert msg['content'] == 'テストメッセージ', f'Expected content=テストメッセージ, got {msg["content"]}'
assert msg['read'] == False, f'Expected read=False, got {msg["read"]}'
assert msg['id'].startswith('msg_'), f'Message ID should start with msg_, got {msg["id"]}'

print('T-003: PASS')
EOF
}

# =============================================================================
# T-004: 正常書き込み — 既存inboxへの追記
# =============================================================================

@test "T-004: append to existing inbox → preserves existing messages, adds new one" {
    # 1件目の書き込み
    bash "$TEST_INBOX_WRITE" "test_agent" "メッセージ1" "type1" "sender1"

    # 2件目の書き込み
    run bash "$TEST_INBOX_WRITE" "test_agent" "メッセージ2" "type2" "sender2"
    [ "$status" -eq 0 ]

    # python3で検証
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

assert len(data['messages']) == 2, f'Expected 2 messages, got {len(data["messages"])}'

# 順序検証（1件目が先頭）
assert data['messages'][0]['content'] == 'メッセージ1', 'First message mismatch'
assert data['messages'][1]['content'] == 'メッセージ2', 'Second message mismatch'

print('T-004: PASS')
EOF
}

# =============================================================================
# T-005: メッセージID一意性
# =============================================================================

@test "T-005: message ID uniqueness → 2 rapid writes produce different IDs" {
    # 2回連続書き込み
    bash "$TEST_INBOX_WRITE" "test_agent" "メッセージA"
    bash "$TEST_INBOX_WRITE" "test_agent" "メッセージB"

    # python3で検証
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

assert len(data['messages']) == 2, 'Expected 2 messages'

id1 = data['messages'][0]['id']
id2 = data['messages'][1]['id']

assert id1 != id2, f'Message IDs should be different: {id1} == {id2}'

print('T-005: PASS')
EOF
}

# =============================================================================
# T-006: デフォルト値 — type未指定でwake_up
# =============================================================================

@test "T-006: type/from default values → type=wake_up, from=unknown when not specified" {
    run bash "$TEST_INBOX_WRITE" "test_agent" "デフォルトテスト"
    [ "$status" -eq 0 ]

    # python3で検証
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

msg = data['messages'][0]

assert msg['type'] == 'wake_up', f'Expected type=wake_up, got {msg["type"]}'
assert msg['from'] == 'unknown', f'Expected from=unknown, got {msg["from"]}'

print('T-006: PASS')
EOF
}

# =============================================================================
# T-007: カスタムtype/from指定
# =============================================================================

@test "T-007: custom type/from → 4th and 5th args set type and from correctly" {
    run bash "$TEST_INBOX_WRITE" "test_agent" "カスタムメッセージ" "custom_type" "custom_sender"
    [ "$status" -eq 0 ]

    # python3で検証
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

msg = data['messages'][0]

assert msg['type'] == 'custom_type', f'Expected type=custom_type, got {msg["type"]}'
assert msg['from'] == 'custom_sender', f'Expected from=custom_sender, got {msg["from"]}'

print('T-007: PASS')
EOF
}

# =============================================================================
# T-008: Overflow Protection — 50件超で古い既読を削除
# =============================================================================

@test "T-008: overflow protection at 50 messages → oldest read messages removed" {
    # 既読メッセージ60件を事前に作成
    "$VENV_PYTHON" <<EOF
import yaml

messages = []
for i in range(60):
    messages.append({
        'id': f'msg_old_{i:03d}',
        'from': 'test_sender',
        'timestamp': f'2026-01-01T00:{i:02d}:00',
        'type': 'test_type',
        'content': f'既読メッセージ {i}',
        'read': True
    })

data = {'messages': messages}

with open('$TEST_INBOX_DIR/test_agent.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
EOF

    # 新規メッセージ1件書き込み
    run bash "$TEST_INBOX_WRITE" "test_agent" "新規メッセージ"
    [ "$status" -eq 0 ]

    # 検証: 合計50件以下、新規メッセージは存在
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

assert len(data['messages']) <= 50, f'Expected <= 50 messages, got {len(data["messages"])}'

# 新規メッセージが含まれていることを確認
new_msg_found = any(msg['content'] == '新規メッセージ' for msg in data['messages'])
assert new_msg_found, 'New message not found after overflow protection'

print('T-008: PASS')
EOF
}

# =============================================================================
# T-009: Overflow Protection — 未読メッセージは削除されない
# =============================================================================

@test "T-009: overflow preserves unread → unread messages are NOT removed even when over 50" {
    # 未読20件 + 既読40件を事前に作成
    "$VENV_PYTHON" <<EOF
import yaml

messages = []

# 未読20件
for i in range(20):
    messages.append({
        'id': f'msg_unread_{i:03d}',
        'from': 'test_sender',
        'timestamp': f'2026-01-01T00:{i:02d}:00',
        'type': 'test_type',
        'content': f'未読メッセージ {i}',
        'read': False
    })

# 既読40件
for i in range(40):
    messages.append({
        'id': f'msg_read_{i:03d}',
        'from': 'test_sender',
        'timestamp': f'2026-01-01T01:{i:02d}:00',
        'type': 'test_type',
        'content': f'既読メッセージ {i}',
        'read': True
    })

data = {'messages': messages}

with open('$TEST_INBOX_DIR/test_agent.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
EOF

    # 新規メッセージ1件書き込み（未読20→21件になる）
    run bash "$TEST_INBOX_WRITE" "test_agent" "新規未読"
    [ "$status" -eq 0 ]

    # 検証: 未読21件が全て保持される
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

unread_count = sum(1 for msg in data['messages'] if not msg.get('read', False))

assert unread_count == 21, f'Expected 21 unread messages, got {unread_count}'

# 元の未読メッセージが全て残っていることを確認
for i in range(20):
    found = any(msg['content'] == f'未読メッセージ {i}' for msg in data['messages'])
    assert found, f'Unread message {i} was removed'

print('T-009: PASS')
EOF
}

# =============================================================================
# T-010: flock競合時のリトライ（並行書き込みテスト）
# =============================================================================

@test "T-010: concurrent writes (flock test) → 8 parallel writes all succeed, no data loss" {
    # 並行書き込み用のスクリプトを作成
    cat > "$TEST_TMPDIR/parallel_write.sh" <<'SCRIPT_EOF'
#!/bin/bash
INBOX_WRITE="$1"
AGENT="$2"
ID="$3"
bash "$INBOX_WRITE" "$AGENT" "並行メッセージ $ID" "concurrent" "writer_$ID" 2>/dev/null
SCRIPT_EOF
    chmod +x "$TEST_TMPDIR/parallel_write.sh"

    # 8個の並行書き込みプロセスを起動
    for i in {1..8}; do
        "$TEST_TMPDIR/parallel_write.sh" "$TEST_INBOX_WRITE" "test_agent" "$i" &
    done

    # 全プロセスの完了を待つ
    wait

    # 検証: 8件全てが書き込まれていること
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

assert len(data['messages']) == 8, f'Expected 8 messages, got {len(data["messages"])}'

# 全てのIDが異なることを確認
ids = [msg['id'] for msg in data['messages']]
assert len(ids) == len(set(ids)), 'Duplicate message IDs found'

print('T-010: PASS')
EOF
}

# =============================================================================
# T-011: 特殊文字のエスケープ処理
# =============================================================================

@test "T-011: special characters in content → YAML special chars handled safely" {
    # YAML特殊文字を含むメッセージ
    SPECIAL_CONTENT="引用符: \"test\" と 'test'
改行を含む
コロン: key: value
ブレース: {key: value}
配列: [1, 2, 3]"

    run bash "$TEST_INBOX_WRITE" "test_agent" "$SPECIAL_CONTENT"
    [ "$status" -eq 0 ]

    # 検証: 特殊文字が正しく保存・復元されること
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

msg = data['messages'][0]

expected_content = '''引用符: "test" と 'test'
改行を含む
コロン: key: value
ブレース: {key: value}
配列: [1, 2, 3]'''

assert msg['content'] == expected_content, f'Content mismatch: {msg["content"]}'

print('T-011: PASS')
EOF
}

# =============================================================================
# T-012: inbox初期化 — ディレクトリ自動作成
# =============================================================================

@test "T-012: auto-create inbox directory → missing queue/inbox/ directory is created" {
    # queue/inbox/ ディレクトリを削除
    rm -rf "$TEST_INBOX_DIR"

    # ディレクトリが存在しないことを確認
    [ ! -d "$TEST_INBOX_DIR" ]

    # メッセージ書き込み
    run bash "$TEST_INBOX_WRITE" "test_agent" "自動作成テスト"
    [ "$status" -eq 0 ]

    # ディレクトリとファイルが作成されていることを確認
    [ -d "$TEST_INBOX_DIR" ]
    [ -f "$TEST_INBOX_DIR/test_agent.yaml" ]

    # 内容検証
    "$VENV_PYTHON" <<EOF
import yaml

with open('$TEST_INBOX_DIR/test_agent.yaml') as f:
    data = yaml.safe_load(f)

assert len(data['messages']) == 1, 'Expected 1 message after auto-create'

print('T-012: PASS')
EOF
}
