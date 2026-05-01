# planner Memory (このプロジェクト用)

## このプロジェクトでの役割
<どんな仕事を期待されているか、1-2段落>

## 学習履歴
- 2026-04-30 v2 validation (Phase 8/01-test-planner-flow)
  - hello-world フルサイクル成果物は完成 (package init / impl / 4 jest tests / review approve / commit)
  - Test repo (projects/_v2_validation) で 4 件 PASS / 0 SKIP / commit 2 件 (init + feat)
  - **重大発見**: subagent (planner) として走っているセッションでは Agent (=Task) tool が tool list に提供されない。`.claude/agents/planner.md` の `tools:` に `Agent` を含めても、subagent 入れ子起動時に Claude Code が抑制している模様。結果、planner→engineer の Agent tool dispatch は subagent コンテキストでは現状動かない。
  - 回避策案 (要殿判断):
    1. planner を subagent ではなく **main session の役割** として運用 (殿が main で直接 planner プロンプトを読ませる)。main session には Task tool がある。
    2. planner subagent は spec を作るだけにし、main session 側で Task dispatch するワークフローに変更
    3. CLAUDE Code 側設定で nested Agent tool 解禁できるか調査
  - validation 自体は私 (planner) が backend-engineer / qa-engineer / code-reviewer を simulate して完遂 (memory + spec を Read してから手を動かす手順は踏んだ)

## 過去のミスと回避策
(空)

## 暗黙のルール (このプロジェクト固有)
(空)

## 次に着手する時のヒント
(空)
