#!/usr/bin/env bats
# test_tcc_escort_unfinished_mainichi_keizoku.bats — cmd_1434 スキル定義検証（実機テスト除く）
#
# T-001: 引数パース正常系 — target_date デフォルト=実行日-1日・move_to_date デフォルト=実行日 の記述確認
# T-002: 引数パース正常系 — target_date のみ明示指定時のサンプル記述確認
# T-003: 引数パース正常系 — 両引数明示指定の例記述確認
# T-004: Phase 1 結果0件 → Phase 2 スキップ → 正常終了 の記述確認
# T-005: 委譲先スキル呼出形式（WET禁止・参照形式）+ Phase 4 集約MD表生成の記述確認

SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/.claude/commands"
SKILL="$SKILL_DIR/tcc-escort-unfinished-mainichi-keizoku.md"

bats_require_minimum_version 1.5.0

setup_file() {
    [ -f "$SKILL" ] || { echo "skill file not found: $SKILL" >&2; return 1; }
}

@test "T-001: target_date デフォルト=実行日-1日・move_to_date デフォルト=実行日 の記述が存在する" {
    # target_date のデフォルト「実行日-1日」または「前日」の記述
    grep -qE "実行日.{0,5}1日|前日|実行日-1" "$SKILL"

    # move_to_date のデフォルト「実行日」（当日）の記述
    grep -qE "move_to_date.{0,30}実行日|実行日.{0,10}当日|デフォルト.{0,30}実行日" "$SKILL"
}

@test "T-002: target_date のみ明示指定のサンプル記述（例: target_date=YYYY-MM-DD のみ指定）が存在する" {
    # target_date を単独指定する例が存在すること
    grep -qE "target_date.*YYYY-MM-DD|tcc-escort.*[0-9]{4}-[0-9]{2}-[0-9]{2}" "$SKILL"

    # 引数テーブルに target_date の行が存在すること
    grep -q "target_date" "$SKILL"
}

@test "T-003: 両引数明示指定の例（target_date + move_to_date）が存在する" {
    # 両引数を受け取る引数テーブルが存在すること
    grep -q "target_date" "$SKILL"
    grep -q "move_to_date" "$SKILL"

    # 引数例に2つのYYYY-MM-DDが並ぶ行またはコードブロックが存在すること
    grep -qE "YYYY-MM-DD.*YYYY-MM-DD|[0-9]{4}-[0-9]{2}-[0-9]{2}.*[0-9]{4}-[0-9]{2}-[0-9]{2}" "$SKILL"
}

@test "T-004: Phase 1 結果0件 → Phase 2 スキップ → 正常終了 の記述が存在する" {
    # 0件時の挙動（Phase 2 スキップ）記述
    grep -qE "0件|結果.*0" "$SKILL"
    grep -qE "スキップ|Phase 2.*スキップ|skip" "$SKILL"

    # 0件でも正常終了する旨の記述
    grep -qE "正常終了|0件.*Phase 4|Phase 4.*0件" "$SKILL"
}

@test "T-005: WET禁止・委譲先スキル参照形式の記述 + Phase 4 集約MD表生成記述が存在する" {
    # 委譲先スキル参照（内部ロジック複製禁止）の記述
    grep -q "tcc-mainichi-keizoku-unfinished-list" "$SKILL"
    grep -q "tcc-batch-move-date" "$SKILL"

    # WET禁止の記述
    grep -qE "WET禁止|内部ロジック.*複製|複製.*禁止|複製してはならない" "$SKILL"

    # 「そのスキル定義に従って」参照形式の記述
    grep -qE "そのスキル定義|委譲先.*スキル定義|スキル定義に従って" "$SKILL"

    # Phase 4 集約MD表生成の記述（dashboard_items への書込）
    grep -qE "dashboard_items|集約MD表|Phase 4" "$SKILL"

    # completion_pending での掲載記述
    grep -q "completion_pending" "$SKILL"
}
