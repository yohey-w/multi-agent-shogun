#!/usr/bin/env bats
# test_dynamic_model_routing.bats — Dynamic Model Routing Phase 1 ユニットテスト
# DMR-SPEC-001 準拠 (TC-DMR-001〜055)
# Issue #53 / TDD Red Phase

# --- セットアップ ---

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # Phase 1 テスト用: capability_tiers定義済み
    cat > "${TEST_TMP}/settings_with_tiers.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: codex
      model: gpt-5.3-codex-spark
    ashigaru2:
      type: claude
      model: claude-sonnet-4-5-20250929
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  gpt-5.3:
    max_bloom: 4
    cost_group: chatgpt_pro
  claude-sonnet-4-5-20250929:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
YAML

    # capability_tiersセクション不在（後方互換テスト）
    cat > "${TEST_TMP}/settings_no_tiers.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: codex
      model: gpt-5.3-codex-spark
YAML

    # 空ファイル
    cat > "${TEST_TMP}/settings_empty.yaml" << 'YAML'
YAML

    # YAML構文エラー
    cat > "${TEST_TMP}/settings_broken.yaml" << 'YAML'
capability_tiers:
  model: [broken yaml
  agents: {{invalid
YAML

    # bloom_routing設定テスト用
    cat > "${TEST_TMP}/settings_bloom_auto.yaml" << 'YAML'
bloom_routing: auto
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
YAML

    cat > "${TEST_TMP}/settings_bloom_manual.yaml" << 'YAML'
bloom_routing: manual
YAML

    cat > "${TEST_TMP}/settings_bloom_off.yaml" << 'YAML'
bloom_routing: "off"
YAML

    cat > "${TEST_TMP}/settings_bloom_invalid.yaml" << 'YAML'
bloom_routing: invalid_value
YAML

    # コスト優先テスト用: 同一max_bloomで異なるcost_group
    cat > "${TEST_TMP}/settings_cost_priority.yaml" << 'YAML'
capability_tiers:
  model-chatgpt-a:
    max_bloom: 4
    cost_group: chatgpt_pro
  model-claude-a:
    max_bloom: 4
    cost_group: claude_max
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
YAML

    # Subscription pattern テスト用: Claude onlyパターン
    cat > "${TEST_TMP}/settings_claude_only.yaml" << 'YAML'
cli:
  default: claude
capability_tiers:
  claude-sonnet-4-5-20250929:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
YAML

    # Subscription pattern テスト用: ChatGPT onlyパターン
    cat > "${TEST_TMP}/settings_chatgpt_only.yaml" << 'YAML'
cli:
  default: codex
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  gpt-5.3:
    max_bloom: 4
    cost_group: chatgpt_pro
YAML

    # Subscription pattern テスト用: available_cost_groups明示定義
    cat > "${TEST_TMP}/settings_explicit_groups.yaml" << 'YAML'
cli:
  default: claude
available_cost_groups:
  - claude_max
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  gpt-5.3:
    max_bloom: 4
    cost_group: chatgpt_pro
  claude-sonnet-4-5-20250929:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
YAML

    # Subscription pattern テスト用: available_cost_groups chatgpt_proのみ
    cat > "${TEST_TMP}/settings_chatgpt_groups.yaml" << 'YAML'
cli:
  default: codex
available_cost_groups:
  - chatgpt_pro
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  gpt-5.3:
    max_bloom: 4
    cost_group: chatgpt_pro
  claude-sonnet-4-5-20250929:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
YAML

    # Phase 3 テスト用: gunshi_analysis.yaml フィクスチャ

    # 正常な分析YAML（全フィールド定義）
    cat > "${TEST_TMP}/analysis_valid.yaml" << 'YAML'
task_id: subtask_test001
timestamp: "2026-02-18T00:00:00+09:00"
analysis:
  bloom_level: 4
  bloom_reasoning: "バグ修正タスク。コード読解+原因分析が必要"
  recommended_model: "gpt-5.3"
  recommended_cli: "codex"
  confidence: 0.85
  quality_criteria:
    - "既存テストがパスすること"
    - "変更箇所にユニットテスト追加"
  qc_method: automated
  pdca_needed: false
YAML

    # #48フィールド省略（#53領域のみ）
    cat > "${TEST_TMP}/analysis_no48.yaml" << 'YAML'
task_id: subtask_test002
timestamp: "2026-02-18T00:00:00+09:00"
analysis:
  bloom_level: 3
  bloom_reasoning: "テンプレ適用タスク"
  recommended_model: "gpt-5.3-codex-spark"
  recommended_cli: "codex"
  confidence: 0.92
YAML

    # bloom_level範囲外
    cat > "${TEST_TMP}/analysis_bad_bloom.yaml" << 'YAML'
task_id: subtask_test003
timestamp: "2026-02-18T00:00:00+09:00"
analysis:
  bloom_level: 7
  bloom_reasoning: "invalid level"
  recommended_model: "gpt-5.3"
  recommended_cli: "codex"
  confidence: 0.5
YAML

    # confidence範囲外
    cat > "${TEST_TMP}/analysis_bad_confidence.yaml" << 'YAML'
task_id: subtask_test004
timestamp: "2026-02-18T00:00:00+09:00"
analysis:
  bloom_level: 4
  bloom_reasoning: "normal task"
  recommended_model: "gpt-5.3"
  recommended_cli: "codex"
  confidence: 2.0
YAML

    # find_agent_for_model テスト用: 混合CLI設定
    cat > "${TEST_TMP}/settings_mixed_cli.yaml" << 'YAML'
cli:
  default: claude
  agents:
    karo:
      type: claude
      model: claude-sonnet-4-5-20250929
    ashigaru1:
      type: codex
      model: gpt-5.3-codex-spark
    ashigaru2:
      type: codex
      model: gpt-5.3-codex-spark
    ashigaru3:
      type: codex
      model: gpt-5.3-codex-spark
    ashigaru4:
      type: claude
      model: claude-sonnet-4-6
    ashigaru5:
      type: claude
      model: claude-sonnet-4-6
    ashigaru6:
      type: claude
      model: claude-opus-4-6
    ashigaru7:
      type: claude
      model: claude-opus-4-6
    gunshi:
      type: claude
      model: opus
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  claude-sonnet-4-6:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
bloom_routing: "manual"
YAML

    # find_agent_for_model テスト用: 全足軽Spark
    cat > "${TEST_TMP}/settings_all_spark.yaml" << 'YAML'
cli:
  default: codex
  agents:
    ashigaru1:
      type: codex
      model: gpt-5.3-codex-spark
    ashigaru2:
      type: codex
      model: gpt-5.3-codex-spark
    ashigaru3:
      type: codex
      model: gpt-5.3-codex-spark
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
YAML

    # bloom_model_preference テスト用: 標準preference定義（4段構成）
    cat > "${TEST_TMP}/settings_with_preference.yaml" << 'YAML'
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  claude-haiku-4-5-20251001:
    max_bloom: 3
    cost_group: claude_max
  gpt-5.3:
    max_bloom: 5
    cost_group: chatgpt_pro
  claude-sonnet-4-6:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
bloom_model_preference:
  L1-L2:
    - gpt-5.3-codex-spark
    - claude-haiku-4-5-20251001
  L3:
    - gpt-5.3
    - gpt-5.3-codex-spark
    - claude-haiku-4-5-20251001
  L4-L5:
    - claude-sonnet-4-6
    - gpt-5.3
  L6:
    - claude-opus-4-6
    - claude-sonnet-4-6
YAML

    # bloom_model_preference テスト用: 1番目capability不足 → 2番目fallback
    cat > "${TEST_TMP}/settings_preference_cap_fallback.yaml" << 'YAML'
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  claude-sonnet-4-6:
    max_bloom: 5
    cost_group: claude_max
bloom_model_preference:
  L4-L5:
    - gpt-5.3-codex-spark
    - claude-sonnet-4-6
YAML

    # bloom_model_preference テスト用: preference全滅 → cost_priorityへfallback
    cat > "${TEST_TMP}/settings_preference_all_fail.yaml" << 'YAML'
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  claude-haiku-4-5-20251001:
    max_bloom: 3
    cost_group: claude_max
  claude-sonnet-4-6:
    max_bloom: 5
    cost_group: claude_max
bloom_model_preference:
  L4-L5:
    - gpt-5.3-codex-spark
    - claude-haiku-4-5-20251001
YAML

    # bloom_model_preference テスト用: available_cost_groups=[claude_max]でSparkを除外
    cat > "${TEST_TMP}/settings_preference_claude_only.yaml" << 'YAML'
available_cost_groups:
  - claude_max
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  claude-haiku-4-5-20251001:
    max_bloom: 3
    cost_group: claude_max
  claude-sonnet-4-6:
    max_bloom: 5
    cost_group: claude_max
bloom_model_preference:
  L1-L3:
    - gpt-5.3-codex-spark
    - claude-haiku-4-5-20251001
YAML

    # .venvへのsymlinkを作成
    if [ -d "${PROJECT_ROOT}/.venv" ]; then
        ln -sf "${PROJECT_ROOT}/.venv" "${TEST_TMP}/.venv"
    fi
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ヘルパー: 特定のsettings.yamlでcli_adapterをロード
load_adapter_with() {
    local settings_file="$1"
    export CLI_ADAPTER_SETTINGS="$settings_file"
    export CLI_ADAPTER_PROJECT_ROOT="$PROJECT_ROOT"
    source "${PROJECT_ROOT}/lib/cli_adapter.sh"
}

# =============================================================================
# TC-DMR-001〜003: FR-01 settings.yaml capability_tiersセクション
# =============================================================================

@test "TC-DMR-001: FR-01 capability_tiers基本読取 — パースエラーなし" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    # get_capability_tier が定義されている（関数が存在する）
    type get_capability_tier &>/dev/null
    # Spark の max_bloom が読取可能
    result=$(get_capability_tier "gpt-5.3-codex-spark")
    [ "$result" = "3" ]
}

@test "TC-DMR-002: FR-01 capability_tiersセクション不在 — 後方互換" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    # エラーにならず、デフォルト値(6)を返す
    result=$(get_capability_tier "gpt-5.3-codex-spark")
    [ "$result" = "6" ]
}

@test "TC-DMR-003: FR-01 cost_group読取" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_cost_group "gpt-5.3-codex-spark")
    [ "$result" = "chatgpt_pro" ]
}

# =============================================================================
# TC-DMR-010〜017: FR-02 get_capability_tier()
# =============================================================================

@test "TC-DMR-010: FR-02 Spark → 3" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_capability_tier "gpt-5.3-codex-spark")
    [ "$result" = "3" ]
}

@test "TC-DMR-011: FR-02 Codex 5.3 → 4" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_capability_tier "gpt-5.3")
    [ "$result" = "4" ]
}

@test "TC-DMR-012: FR-02 Sonnet Thinking → 5" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_capability_tier "claude-sonnet-4-5-20250929")
    [ "$result" = "5" ]
}

@test "TC-DMR-013: FR-02 Opus Thinking → 6" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_capability_tier "claude-opus-4-6")
    [ "$result" = "6" ]
}

@test "TC-DMR-014: FR-02 未定義モデル → 6" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_capability_tier "unknown-model")
    [ "$result" = "6" ]
}

@test "TC-DMR-015: FR-02 capability_tiersセクション不在 → 6" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result=$(get_capability_tier "gpt-5.3-codex-spark")
    [ "$result" = "6" ]
}

@test "TC-DMR-016: FR-02 YAML破損 → 6" {
    load_adapter_with "${TEST_TMP}/settings_broken.yaml"
    result=$(get_capability_tier "gpt-5.3-codex-spark")
    [ "$result" = "6" ]
}

@test "TC-DMR-017: FR-02 空文字入力 → 6" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_capability_tier "")
    [ "$result" = "6" ]
}

# =============================================================================
# TC-DMR-020〜029: FR-03 get_recommended_model()
# =============================================================================

@test "TC-DMR-020: FR-03 L1 → Spark" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 1)
    [ "$result" = "gpt-5.3-codex-spark" ]
}

@test "TC-DMR-021: FR-03 L2 → Spark" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 2)
    [ "$result" = "gpt-5.3-codex-spark" ]
}

@test "TC-DMR-022: FR-03 L3 → Spark" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 3)
    [ "$result" = "gpt-5.3-codex-spark" ]
}

@test "TC-DMR-023: FR-03 L4 → Codex 5.3" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 4)
    [ "$result" = "gpt-5.3" ]
}

@test "TC-DMR-024: FR-03 L5 → Sonnet Thinking" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 5)
    [ "$result" = "claude-sonnet-4-5-20250929" ]
}

@test "TC-DMR-025: FR-03 L6 → Opus Thinking" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 6)
    [ "$result" = "claude-opus-4-6" ]
}

@test "TC-DMR-026: FR-03 capability_tiersセクション不在 → 空文字" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result=$(get_recommended_model 3)
    [ "$result" = "" ]
}

@test "TC-DMR-027: FR-03 範囲外(0) → exit 1" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run get_recommended_model 0
    [ "$status" -eq 1 ]
}

@test "TC-DMR-028: FR-03 範囲外(7) → exit 1" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run get_recommended_model 7
    [ "$status" -eq 1 ]
}

@test "TC-DMR-029: FR-03 コスト優先 — chatgpt_proが優先" {
    load_adapter_with "${TEST_TMP}/settings_cost_priority.yaml"
    result=$(get_recommended_model 4)
    [ "$result" = "model-chatgpt-a" ]
}

# =============================================================================
# TC-DMR-030〜033: FR-04 get_cost_group()
# =============================================================================

@test "TC-DMR-030: FR-04 Spark → chatgpt_pro" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_cost_group "gpt-5.3-codex-spark")
    [ "$result" = "chatgpt_pro" ]
}

@test "TC-DMR-031: FR-04 Opus → claude_max" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_cost_group "claude-opus-4-6")
    [ "$result" = "claude_max" ]
}

@test "TC-DMR-032: FR-04 未定義モデル → unknown" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_cost_group "unknown-model")
    [ "$result" = "unknown" ]
}

@test "TC-DMR-033: FR-04 capability_tiersセクション不在 → unknown" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result=$(get_cost_group "gpt-5.3-codex-spark")
    [ "$result" = "unknown" ]
}

# =============================================================================
# TC-DMR-040〜041: NFR-01 後方互換性
# =============================================================================

@test "TC-DMR-040: NFR-01 既存get_cli_type回帰なし" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    # 既存関数がcapability_tiers追加後も正常動作
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "codex" ]
}

@test "TC-DMR-041: NFR-01 既存get_agent_model回帰なし" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result=$(get_agent_model "ashigaru1")
    [ "$result" = "gpt-5.3-codex-spark" ]
}

# =============================================================================
# TC-DMR-050: NFR-05 テスト容易性
# =============================================================================

@test "TC-DMR-050: NFR-05 CLI_ADAPTER_SETTINGS注入" {
    # 異なるsettingsファイルを注入してテスト可能なことを確認
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result1=$(get_capability_tier "gpt-5.3-codex-spark")
    [ "$result1" = "3" ]

    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result2=$(get_capability_tier "gpt-5.3-codex-spark")
    [ "$result2" = "6" ]
}

# =============================================================================
# TC-DMR-055: NFR-06 冪等性
# =============================================================================

@test "TC-DMR-055: NFR-06 get_recommended_model連続呼出で同一結果" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result1=$(get_recommended_model 4)
    result2=$(get_recommended_model 4)
    [ "$result1" = "$result2" ]
}

# =============================================================================
# TC-DMR-220〜224: FR-09 bloom_routing設定（Phase 3だがL1で先行テスト可能）
# =============================================================================

@test "TC-DMR-220: FR-09 bloom_routing=auto読取" {
    load_adapter_with "${TEST_TMP}/settings_bloom_auto.yaml"
    result=$(_cli_adapter_read_yaml "bloom_routing" "off")
    [ "$result" = "auto" ]
}

@test "TC-DMR-221: FR-09 bloom_routing=manual読取" {
    load_adapter_with "${TEST_TMP}/settings_bloom_manual.yaml"
    result=$(_cli_adapter_read_yaml "bloom_routing" "off")
    [ "$result" = "manual" ]
}

@test "TC-DMR-222: FR-09 bloom_routing=off読取" {
    load_adapter_with "${TEST_TMP}/settings_bloom_off.yaml"
    result=$(_cli_adapter_read_yaml "bloom_routing" "off")
    [ "$result" = "off" ]
}

@test "TC-DMR-223: FR-09 bloom_routing未定義 → off" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result=$(_cli_adapter_read_yaml "bloom_routing" "off")
    [ "$result" = "off" ]
}

# =============================================================================
# Phase 2: TC-DMR-100〜142 — Karo manual model_switch
# =============================================================================

# --- TC-DMR-100〜103: FR-05 model_switch判定 ---

@test "TC-DMR-100: FR-05 switch不要 — bloom=3, model=spark" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run needs_model_switch "gpt-5.3-codex-spark" 3
    [ "$status" -eq 0 ]
    [ "$output" = "no" ]
}

@test "TC-DMR-101: FR-05 switch必要 — bloom=4, model=spark" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run needs_model_switch "gpt-5.3-codex-spark" 4
    [ "$status" -eq 0 ]
    [ "$output" = "yes" ]
}

@test "TC-DMR-102: FR-05 capability_tiers不在 → 判定スキップ" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    run needs_model_switch "gpt-5.3-codex-spark" 4
    [ "$status" -eq 0 ]
    [ "$output" = "skip" ]
}

@test "TC-DMR-103: FR-05 bloomフィールドなし → 判定スキップ" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run needs_model_switch "gpt-5.3-codex-spark" ""
    [ "$status" -eq 0 ]
    [ "$output" = "skip" ]
}

# --- TC-DMR-110〜113: FR-06 model_switch判定ロジック詳細 ---

@test "TC-DMR-110: FR-06 同CLI内switch — codex spark→codex 5.3" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    # bloom=4, current=spark(max3) → 推奨=codex5.3(max4), both chatgpt_pro
    result=$(get_switch_recommendation "gpt-5.3-codex-spark" 4)
    [[ "$result" == *"gpt-5.3"* ]]
    [[ "$result" == *"same_cost_group"* ]]
}

@test "TC-DMR-111: FR-06 CLI跨ぎ — bloom=5, codex足軽" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    # bloom=5, current=spark(chatgpt_pro) → 推奨=sonnet(claude_max) = cross_cost_group
    result=$(get_switch_recommendation "gpt-5.3-codex-spark" 5)
    [[ "$result" == *"claude-sonnet"* ]]
    [[ "$result" == *"cross_cost_group"* ]]
}

@test "TC-DMR-112: FR-06 switch不要時は現モデル維持" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    # bloom=3, current=spark(max3) → 十分、switchなし
    result=$(get_switch_recommendation "gpt-5.3-codex-spark" 3)
    [ "$result" = "no_switch" ]
}

@test "TC-DMR-113: FR-06 bloom=6でOpusに到達" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_switch_recommendation "gpt-5.3-codex-spark" 6)
    [[ "$result" == *"claude-opus-4-6"* ]]
}

# --- TC-DMR-120〜121: NFR-02 応答速度 ---

@test "TC-DMR-120: NFR-02 get_capability_tier応答速度 500ms以内" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    start=$(date +%s%N)
    get_capability_tier "gpt-5.3-codex-spark" > /dev/null
    end=$(date +%s%N)
    elapsed_ms=$(( (end - start) / 1000000 ))
    [ "$elapsed_ms" -lt 500 ]
}

@test "TC-DMR-121: NFR-02 get_recommended_model応答速度 500ms以内" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    start=$(date +%s%N)
    get_recommended_model 4 > /dev/null
    end=$(date +%s%N)
    elapsed_ms=$(( (end - start) / 1000000 ))
    [ "$elapsed_ms" -lt 500 ]
}

# --- TC-DMR-130〜131: NFR-03 CLI互換性 ---

@test "TC-DMR-130: NFR-03 model_switchはClaude足軽のみ有効" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    # codex足軽: switchは可能だがCLI跨ぎ注意
    result=$(can_model_switch "codex")
    [ "$result" = "limited" ]
}

@test "TC-DMR-131: NFR-03 Claude足軽はfull switch可能" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(can_model_switch "claude")
    [ "$result" = "full" ]
}

# --- TC-DMR-140〜142: NFR-04 コスト最適化 ---

@test "TC-DMR-140: NFR-04 L3にOpus不使用" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 3)
    [ "$result" != "claude-opus-4-6" ]
}

@test "TC-DMR-141: NFR-04 chatgpt_pro優先" {
    load_adapter_with "${TEST_TMP}/settings_cost_priority.yaml"
    result=$(get_recommended_model 4)
    cg=$(get_cost_group "$result")
    [ "$cg" = "chatgpt_pro" ]
}

@test "TC-DMR-142: NFR-04 不要switch抑制" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    # current model can handle bloom level → no switch
    run needs_model_switch "gpt-5.3" 4
    [ "$output" = "no" ]
}

# =============================================================================
# Phase 3: TC-DMR-200〜224 — Gunshi Bloom analysis layer
# =============================================================================

# --- TC-DMR-200〜203: FR-07 gunshi_analysis.yaml スキーマ ---

@test "TC-DMR-200: FR-07 正常YAML — 全フィールド定義" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run validate_gunshi_analysis "${TEST_TMP}/analysis_valid.yaml"
    [ "$status" -eq 0 ]
    [ "$output" = "valid" ]
}

@test "TC-DMR-201: FR-07 #48フィールド省略 — パースエラーなし" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run validate_gunshi_analysis "${TEST_TMP}/analysis_no48.yaml"
    [ "$status" -eq 0 ]
    [ "$output" = "valid" ]
}

@test "TC-DMR-202: FR-07 bloom_level範囲外(0,7) — バリデーションエラー" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run validate_gunshi_analysis "${TEST_TMP}/analysis_bad_bloom.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bloom_level"* ]]
}

@test "TC-DMR-203: FR-07 confidence範囲外(-1, 2.0) — バリデーションエラー" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    run validate_gunshi_analysis "${TEST_TMP}/analysis_bad_confidence.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" == *"confidence"* ]]
}

# --- TC-DMR-210〜214: FR-08 Bloom分析トリガー判定ロジック ---
# L2統合テストのうち、判定ロジック部分をL1関数に切り出してテスト

@test "TC-DMR-210: FR-08 auto → 全タスク分析トリガー" {
    load_adapter_with "${TEST_TMP}/settings_bloom_auto.yaml"
    result=$(should_trigger_bloom_analysis "auto" "false")
    [ "$result" = "yes" ]
}

@test "TC-DMR-211: FR-08 manual + required=true → 分析トリガー" {
    load_adapter_with "${TEST_TMP}/settings_bloom_manual.yaml"
    result=$(should_trigger_bloom_analysis "manual" "true")
    [ "$result" = "yes" ]
}

@test "TC-DMR-211b: FR-08 manual + required=false → トリガーなし" {
    load_adapter_with "${TEST_TMP}/settings_bloom_manual.yaml"
    result=$(should_trigger_bloom_analysis "manual" "false")
    [ "$result" = "no" ]
}

@test "TC-DMR-212: FR-08 off → 分析なし" {
    load_adapter_with "${TEST_TMP}/settings_bloom_off.yaml"
    result=$(should_trigger_bloom_analysis "off" "true")
    [ "$result" = "no" ]
}

@test "TC-DMR-213: FR-08 bloom_routing未定義 → off扱い → 分析なし" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    # bloom_routing not set → get_bloom_routing returns "off"
    routing=$(get_bloom_routing)
    result=$(should_trigger_bloom_analysis "$routing" "true")
    [ "$result" = "no" ]
}

@test "TC-DMR-214: FR-08 should_trigger_bloom_analysis fallback引数" {
    load_adapter_with "${TEST_TMP}/settings_bloom_auto.yaml"
    # gunshi_available=no → fallback to Phase 2
    result=$(should_trigger_bloom_analysis "auto" "false" "no")
    [ "$result" = "fallback" ]
}

# --- TC-DMR-224: FR-09 不正値 → off + stderr警告 ---

@test "TC-DMR-224: FR-09 bloom_routing不正値 → off + stderr警告" {
    load_adapter_with "${TEST_TMP}/settings_bloom_invalid.yaml"
    result=$(get_bloom_routing 2>/tmp/dmr_stderr_test)
    [ "$result" = "off" ]
    # stderrに警告が出力されている
    grep -q "bloom_routing" /tmp/dmr_stderr_test || grep -q "invalid" /tmp/dmr_stderr_test
    rm -f /tmp/dmr_stderr_test
}

# =============================================================================
# Phase 4: TC-DMR-300〜303 — Full auto-selection (品質フィードバック)
# =============================================================================

@test "TC-DMR-300: FR-10 履歴追記 — model_performance.yamlに1行追記" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    local perf_file="${TEST_TMP}/model_performance.yaml"
    # 初回追記
    run append_model_performance "$perf_file" "subtask_001" "seo_article" 3 "gpt-5.3-codex-spark" "pass" 0.85
    [ "$status" -eq 0 ]
    # ファイルが生成され、1件のhistoryエントリが存在
    run "$CLI_ADAPTER_PROJECT_ROOT/.venv/bin/python3" -c "
import yaml
with open('${perf_file}') as f:
    doc = yaml.safe_load(f)
print(len(doc.get('history', [])))
"
    [ "$output" = "1" ]
}

@test "TC-DMR-301: FR-10 履歴読取 — task_type×bloom_level別の集計" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    local perf_file="${TEST_TMP}/model_performance.yaml"
    # 3件追記
    append_model_performance "$perf_file" "subtask_001" "seo_article" 3 "gpt-5.3-codex-spark" "pass" 0.90
    append_model_performance "$perf_file" "subtask_002" "seo_article" 3 "gpt-5.3-codex-spark" "pass" 0.85
    append_model_performance "$perf_file" "subtask_003" "seo_article" 3 "gpt-5.3-codex-spark" "fail" 0.40
    # 集計: seo_article × bloom3 → 3件
    result=$(get_model_performance_summary "$perf_file" "seo_article" 3)
    [[ "$result" == *"total:3"* ]]
    [[ "$result" == *"pass:2"* ]]
}

@test "TC-DMR-302: FR-10 空ファイル — model_performance.yaml不在でもエラーなし" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    local perf_file="${TEST_TMP}/nonexistent_performance.yaml"
    run get_model_performance_summary "$perf_file" "seo_article" 3
    [ "$status" -eq 0 ]
    [[ "$output" == *"total:0"* ]]
}

@test "TC-DMR-303: FR-10 適合度算出 — pass率が算出可能" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    local perf_file="${TEST_TMP}/model_performance.yaml"
    # 4件: 3 pass, 1 fail → pass_rate=0.75
    append_model_performance "$perf_file" "subtask_001" "bugfix" 4 "gpt-5.3" "pass" 0.90
    append_model_performance "$perf_file" "subtask_002" "bugfix" 4 "gpt-5.3" "pass" 0.85
    append_model_performance "$perf_file" "subtask_003" "bugfix" 4 "gpt-5.3" "pass" 0.80
    append_model_performance "$perf_file" "subtask_004" "bugfix" 4 "gpt-5.3" "fail" 0.30
    result=$(get_model_performance_summary "$perf_file" "bugfix" 4)
    [[ "$result" == *"pass_rate:0.75"* ]]
}

# =============================================================================
# Subscription Patterns: TC-DMR-400〜423
# ユーザー契約パターン対応（Claude only / ChatGPT only / 両方）
# =============================================================================

# --- TC-DMR-400〜402: get_available_cost_groups ---

@test "TC-DMR-400: get_available_cost_groups — 明示定義 claude_maxのみ" {
    load_adapter_with "${TEST_TMP}/settings_explicit_groups.yaml"
    result=$(get_available_cost_groups)
    [ "$result" = "claude_max" ]
}

@test "TC-DMR-401: get_available_cost_groups — 省略時はcapability_tiersから自動推定" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_available_cost_groups)
    # 両方のcost_groupが含まれる（順序不問）
    [[ "$result" == *"chatgpt_pro"* ]]
    [[ "$result" == *"claude_max"* ]]
}

@test "TC-DMR-402: get_available_cost_groups — capability_tiers不在 → 空" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result=$(get_available_cost_groups)
    [ "$result" = "" ]
}

@test "TC-DMR-403: get_available_cost_groups — Claude onlyの自動推定" {
    load_adapter_with "${TEST_TMP}/settings_claude_only.yaml"
    result=$(get_available_cost_groups)
    [ "$result" = "claude_max" ]
}

@test "TC-DMR-404: get_available_cost_groups — ChatGPT onlyの自動推定" {
    load_adapter_with "${TEST_TMP}/settings_chatgpt_only.yaml"
    result=$(get_available_cost_groups)
    [ "$result" = "chatgpt_pro" ]
}

# --- TC-DMR-410〜413: get_recommended_model — 契約パターン別動作 ---

@test "TC-DMR-410: Claude only — L3 → sonnet + overqualified警告" {
    load_adapter_with "${TEST_TMP}/settings_claude_only.yaml"
    result=$(get_recommended_model 3 2>/tmp/dmr_410_stderr)
    [ "$result" = "claude-sonnet-4-5-20250929" ]
    # stderrにoverqualified警告
    grep -q "overqualified" /tmp/dmr_410_stderr
    rm -f /tmp/dmr_410_stderr
}

@test "TC-DMR-411: ChatGPT only — L5 → gpt-5.3 + insufficient警告" {
    load_adapter_with "${TEST_TMP}/settings_chatgpt_only.yaml"
    result=$(get_recommended_model 5 2>/tmp/dmr_411_stderr)
    [ "$result" = "gpt-5.3" ]
    # stderrにinsufficient警告
    grep -q "insufficient" /tmp/dmr_411_stderr
    rm -f /tmp/dmr_411_stderr
}

@test "TC-DMR-412: available_cost_groups=claude_max → chatgpt_proモデルを候補除外" {
    load_adapter_with "${TEST_TMP}/settings_explicit_groups.yaml"
    # L3でもchatgpt_proモデル(Spark)は除外、claude_maxのsonnetが選ばれる
    result=$(get_recommended_model 3)
    [[ "$result" == "claude-sonnet-4-5-20250929" ]]
}

@test "TC-DMR-413: available_cost_groups=chatgpt_pro → claude_maxモデルを候補除外" {
    load_adapter_with "${TEST_TMP}/settings_chatgpt_groups.yaml"
    # L5でもclaude_maxモデル(Sonnet)は除外、chatgpt_proの最大gpt-5.3が選ばれる
    result=$(get_recommended_model 5 2>/dev/null)
    [ "$result" = "gpt-5.3" ]
}

@test "TC-DMR-414: 両方契約 — L3 → Spark（従来通り最安選択）" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(get_recommended_model 3)
    [ "$result" = "gpt-5.3-codex-spark" ]
}

# --- TC-DMR-420〜423: validate_subscription_coverage ---

@test "TC-DMR-420: validate_subscription_coverage — 全Bloomカバー → ok" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    result=$(validate_subscription_coverage)
    [ "$result" = "ok" ]
}

@test "TC-DMR-421: validate_subscription_coverage — ChatGPT only → gap:5,6" {
    load_adapter_with "${TEST_TMP}/settings_chatgpt_only.yaml"
    result=$(validate_subscription_coverage)
    [[ "$result" == *"gap"* ]]
    [[ "$result" == *"5"* ]]
    [[ "$result" == *"6"* ]]
}

@test "TC-DMR-422: validate_subscription_coverage — Claude only → カバー(L5+L6あり)" {
    load_adapter_with "${TEST_TMP}/settings_claude_only.yaml"
    result=$(validate_subscription_coverage)
    # Sonnet(L5)+Opus(L6)でL1-L6全てカバー可能（overqualifiedだが対応可能）
    [ "$result" = "ok" ]
}

@test "TC-DMR-423: validate_subscription_coverage — capability_tiers不在 → 未設定" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    result=$(validate_subscription_coverage)
    [ "$result" = "unconfigured" ]
}

# ============================================================
# TC-FAM-001〜009: find_agent_for_model() — Phase 2 ユニットテスト
# ============================================================
# NOTE: ユニットテスト環境ではtmuxセッションが存在しない。
#       pane_target が空 → 最初の候補を即返す動作になる（設計どおり）。
#       tmux統合はE2Eテストで検証する。

@test "TC-FAM-001: 完全一致の足軽が存在 → ashigaru1 を返す（Spark）" {
    load_adapter_with "${TEST_TMP}/settings_mixed_cli.yaml"
    result=$(find_agent_for_model "gpt-5.3-codex-spark")
    [ "$result" = "ashigaru1" ]
}

@test "TC-FAM-002: Sonnet足軽が存在 → ashigaru4 を返す" {
    load_adapter_with "${TEST_TMP}/settings_mixed_cli.yaml"
    result=$(find_agent_for_model "claude-sonnet-4-6")
    [ "$result" = "ashigaru4" ]
}

@test "TC-FAM-003: Opus足軽が存在 → ashigaru6 を返す" {
    load_adapter_with "${TEST_TMP}/settings_mixed_cli.yaml"
    result=$(find_agent_for_model "claude-opus-4-6")
    [ "$result" = "ashigaru6" ]
}

@test "TC-FAM-004: 対応モデルの足軽がない + 他の足軽が存在 → フォールバック（いずれかの足軽）" {
    load_adapter_with "${TEST_TMP}/settings_mixed_cli.yaml"
    result=$(find_agent_for_model "gpt-5.1-codex-max")
    # 完全一致なし → フォールバックとして番号最小の足軽を返す
    [ -n "$result" ]
    [[ "$result" =~ ^ashigaru[0-9]+$ ]]
}

@test "TC-FAM-005: 引数なし → exit code 1" {
    load_adapter_with "${TEST_TMP}/settings_mixed_cli.yaml"
    run find_agent_for_model
    [ "$status" -eq 1 ]
}

@test "TC-FAM-006: 空文字引数 → exit code 1" {
    load_adapter_with "${TEST_TMP}/settings_mixed_cli.yaml"
    run find_agent_for_model ""
    [ "$status" -eq 1 ]
}

@test "TC-FAM-007: 複数の同モデル足軽 → 番号最小を返す（ashigaru1）" {
    load_adapter_with "${TEST_TMP}/settings_all_spark.yaml"
    result=$(find_agent_for_model "gpt-5.3-codex-spark")
    [ "$result" = "ashigaru1" ]
}

@test "TC-FAM-008: capability_tiersなし設定でも動作する（後方互換）" {
    load_adapter_with "${TEST_TMP}/settings_no_tiers.yaml"
    # no_tiersでもagents定義がある場合はSpark足軽を探して返す
    result=$(find_agent_for_model "gpt-5.3-codex-spark")
    [ "$result" = "ashigaru1" ]
}

@test "TC-FAM-009: 足軽のみ対象（karo, gunshiは除外される）" {
    load_adapter_with "${TEST_TMP}/settings_mixed_cli.yaml"
    # karo, gunshiのモデルを指定 → ashiguruの中に一致なし → フォールバックor先頭
    result=$(find_agent_for_model "claude-sonnet-4-5-20250929")
    # karo (claude-sonnet-4-5-20250929) は候補に入らない
    # 他のashiguruにもこのモデルがないのでフォールバック
    [[ "$result" =~ ^ashigaru[0-9]+$ ]]
}

# =============================================================================
# TC-PREF-001〜007: bloom_model_preference ルーティング
# =============================================================================

@test "TC-PREF-001: preference defined → first choice selected (range key L1-L2)" {
    load_adapter_with "${TEST_TMP}/settings_with_preference.yaml"
    # bloom_level=2, L1-L2の1番目はgpt-5.3-codex-spark
    result=$(get_recommended_model 2)
    [ "$result" = "gpt-5.3-codex-spark" ]
}

@test "TC-PREF-002: first preference capability insufficient → fallback to second" {
    load_adapter_with "${TEST_TMP}/settings_preference_cap_fallback.yaml"
    # bloom_level=4, L4-L5の1番目はgpt-5.3-codex-spark(max_bloom=3 < 4) → skip
    # 2番目はclaude-sonnet-4-6(max_bloom=5 >= 4) → 選択
    result=$(get_recommended_model 4)
    [ "$result" = "claude-sonnet-4-6" ]
}

@test "TC-PREF-003: no preference defined → legacy cost_priority behavior" {
    load_adapter_with "${TEST_TMP}/settings_with_tiers.yaml"
    # settings_with_tiers.yaml にはbloom_model_preferenceなし → 従来動作
    # bloom_level=4: gpt-5.3(mb4,chatgpt_pro=0) vs sonnet(mb5,claude_max=1)
    # cost_priority: chatgpt_pro=0 が優先 → gpt-5.3
    result=$(get_recommended_model 4)
    [ "$result" = "gpt-5.3" ]
}

@test "TC-PREF-004: single key L3 matches bloom_level=3 → gpt-5.3 selected" {
    load_adapter_with "${TEST_TMP}/settings_with_preference.yaml"
    # bloom_level=3, L3（単一キー）の1番目はgpt-5.3
    result=$(get_recommended_model 3)
    [ "$result" = "gpt-5.3" ]
}

@test "TC-PREF-005: all preferred models unavailable → fallback to cost_priority with warning" {
    load_adapter_with "${TEST_TMP}/settings_preference_all_fail.yaml"
    # bloom=4, L4-L5: [spark(max3<4), haiku(max3<4)] → 全滅 → fallback
    # cost_priority fallback: claude-sonnet-4-6(mb5,claude_max)のみ候補
    result=$(get_recommended_model 4 2>/dev/null)
    [ "$result" = "claude-sonnet-4-6" ]
    # stderr に WARNING が出力される
    run bash -c "export CLI_ADAPTER_SETTINGS='${TEST_TMP}/settings_preference_all_fail.yaml'; export CLI_ADAPTER_PROJECT_ROOT='${PROJECT_ROOT}'; source '${PROJECT_ROOT}/lib/cli_adapter.sh' 2>/dev/null; get_recommended_model 4 2>&1 1>/dev/null"
    [[ "$output" =~ "WARNING" ]]
}

@test "TC-PREF-006: available_cost_groups exclusion with preference → skip excluded model, use next" {
    load_adapter_with "${TEST_TMP}/settings_preference_claude_only.yaml"
    # available_cost_groups=[claude_max] → chatgpt_proモデル除外
    # bloom=2, L1-L2: [spark(chatgpt_pro→除外), haiku(claude_max→OK)]
    result=$(get_recommended_model 2)
    [ "$result" = "claude-haiku-4-5-20251001" ]
}

@test "TC-PREF-007: no available_cost_groups → all models are candidates for preference" {
    load_adapter_with "${TEST_TMP}/settings_with_preference.yaml"
    # available_cost_groups未定義 → 全cost_group許可
    # bloom=2, L1-L2の1番目=gpt-5.3-codex-spark(chatgpt_pro) → 除外されずに選択
    result=$(get_recommended_model 2)
    [ "$result" = "gpt-5.3-codex-spark" ]
}
