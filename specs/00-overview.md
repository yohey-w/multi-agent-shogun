# agent-orchestra-makoto-mizuno v2 移行 全体仕様

- **Author**: planner (将軍)
- **Date**: 2026-04-30
- **Status**: Draft (殿承認待ち)
- **Source 決定**: 殿 Q1-Q7 (2026-04-30)

## 1. 北極星 (なぜ v2 に移行するか)

現行 multi-agent-shogun は以下の構造的問題を抱えている:

- **家老 (中間管理層) の伝言ゲーム** で context loss が発生
- **足軽が汎用エージェント** で専門性が薄く、価値が低い
- **軍師の役割名と実態の乖離** (本来は方針策定だが現状はレビュー雑用係)
- **戦国口調** が個人趣味に偏り、商用化・他人共有時の障害
- 結果として **3週間 25 cmd で kindle-snap が殿の核心ニーズを達成できなかった**

v2 ではこれを以下に再設計する:

- **家老廃止** (中間層なし、planner → 専門 agent 直 dispatch)
- **専門 subagent 化** (frontend / backend / db / chrome-extension 等の職能別)
- **軍師分離** (design-reviewer + code-reviewer に明確化)
- **戦国系完全削除** (OSS 公開可能な汎用基盤に)

## 2. 名前と公開戦略

- **リポ名**: `agent-orchestra-makoto-mizuno`
- **ライセンス**: MIT
- **公開**: Public OSS
- **ガード**:
  - main ブランチ保護 (force push / 直 push 禁止、PR 経由のみ)
  - pre-commit / pre-push で secret scan (gitleaks 等) 必須

## 3. アーキテクチャ

### 3.1 Agent 階層

```
┌──────────────────────────────────────┐
│  planner (将軍)                       │  Project-level (.claude/agents/)
│  ├─ タスク受領 (殿 → planner)         │
│  ├─ specs/ に仕様書作成              │
│  ├─ 担当 agent 割当                   │
│  └─ 別 agent に dispatch して実行     │
└──────────────────────────────────────┘
                ↓ Agent tool で起動
┌──────────────────────────────────────┐
│  Reviewers (Project-level)            │
│  ├─ design-reviewer                   │  仕様レビュー、設計承認
│  └─ code-reviewer                     │  コードレビュー、PR レビュー、security 観点
└──────────────────────────────────────┘
                ↓
┌──────────────────────────────────────┐
│  専門 Engineers (User-level)          │  ~/.claude/agents/
│  ├─ frontend-engineer                 │
│  ├─ backend-engineer                  │
│  ├─ infrastructure-engineer           │  Docker/K8s/Cloud/CI/CD 包括
│  ├─ db-engineer                       │  DB 設計・運用 (新規)
│  ├─ chrome-extension-engineer         │
│  ├─ native-app-engineer               │  iOS/Android/Electron
│  ├─ game-engineer                     │
│  ├─ ml-engineer                       │
│  └─ qa-engineer                       │  テスト専門 (新規)
└──────────────────────────────────────┘
```

### 3.2 廃止された役割
- 家老 (karo) — 中間管理層、不要
- 戦国口調エージェント全般 (ashigaru1-7, gunshi) — 専門 subagent に置換
- security-engineer 単独 — code-reviewer に統合

### 3.3 役割未確定 (今後検討)
- ux-designer — 「エージェント以外の仕組み」(skill / tool / mockup自動生成等) で代替検討
- technical-writer — planner / reviewer の責務に統合 or 別途検討

## 4. 仕様書ベース作業フロー

```
1. 殿 → planner: 要件
2. planner: specs/ にタスク分解した仕様書を作成
   各 task spec は Haiku 程度で実行可能な粒度
3. planner: 担当 agent (専門 engineer 名) を spec に明記
4. planner: Agent tool で該当 subagent を dispatch + spec パスを渡す
5. subagent: spec を Read → memory.md context 読込 → 実装 → 結果を出力
6. planner: design-reviewer / code-reviewer を Agent tool で起動 → レビュー
7. 承認 → コミット
```

## 5. ディレクトリ構造 (v2)

```
agent-orchestra-makoto-mizuno/
├── .claude/
│   ├── agents/                     # Project-level subagents
│   │   ├── planner.md
│   │   ├── design-reviewer.md
│   │   └── code-reviewer.md
│   ├── settings.json               # hooks, permissions
│   ├── hooks/
│   │   ├── session_start_context.sh    # memory.md 自動注入
│   │   ├── notify_on_planner_action.sh # 殿通知
│   │   └── pre_push_secret_scan.sh     # 機密漏洩防止
│   └── skills/                     # 既存 skill 機構維持
│       └── ...
├── specs/                          # planner が作成する仕様書
│   └── YYYY-MM-DD-<topic>/
│       ├── 00-overview.md
│       └── 01-NN-<task>.md
├── memory/                         # agent 別 memory.md
│   ├── MEMORY.md                   # index
│   ├── planner.md
│   ├── design-reviewer.md
│   ├── code-reviewer.md
│   └── frontend-engineer.md ...
├── projects/                       # 実プロジェクト (既存)
│   └── ...
├── docs/                           # 公開ドキュメント
│   ├── README.md (英語)
│   ├── README_ja.md (日本語)
│   ├── CONTRIBUTING.md
│   └── architecture.md
├── legacy/                         # 削除直前の旧資産一時置き場
│   └── (削除完了後に消す)
├── CLAUDE.md                       # v2 用、戦国要素ゼロ
├── LICENSE                         # MIT
├── .gitignore                      # secret 漏洩防止
└── .pre-commit-config.yaml         # gitleaks 等
```

## 6. ユーザレベル vs プロジェクトレベル

| 種類 | 場所 | 理由 |
|------|------|------|
| 専門 engineer (frontend, backend, db, ...) | `~/.claude/agents/` | 全プロジェクトで再利用 |
| planner / reviewer | `<project>/.claude/agents/` | プロジェクト固有のルール反映 |
| memory/{agent}.md | `<project>/memory/` | プロジェクトごとに学びを蓄積 |

## 7. memory.md コンセプト

- 各 agent (planner / reviewer / 専門 engineer) ごとに 1 ファイル
- session 開始時に SessionStart hook で自動 Read & context 注入
- 内容: その agent の職務範囲, 学習履歴 (このプロジェクトで学んだ事), 過去ミス, 暗黙ルール
- スキル提案 (skill_candidate) はこの memory に記録 → planner が拾う

## 8. 段階的移行 Phase

| Phase | 目的 | 仕様書 |
|-------|------|--------|
| 0 (実施済) | 現行停止通達 | (本仕様外、bash inbox 通達済) |
| 1 | 凍結とクリーンアップ | `01-freeze-and-cleanup/` |
| 2 | GitHub fork + リポ命名 + 保護 | `02-github-setup/` |
| 3 | User-level subagents 定義 | `03-user-level-subagents/` |
| 4 | Project-level subagents 定義 | `04-project-level-subagents/` |
| 5 | memory + SessionStart hook | `05-memory-and-context/` |
| 6 | CLAUDE.md v2 書き換え | `06-claude-md-rewrite/` |
| 7 | legacy 削除 | `07-legacy-removal/` |
| 8 | 動作検証 | `08-validation/` |

各 Phase の仕様書は **Haiku 程度で実行可能** な粒度にまで分解する。

## 9. 完了基準

- [ ] リポ `agent-orchestra-makoto-mizuno` が GitHub に存在 (Public, MIT)
- [ ] main ブランチ保護 + pre-commit secret scan 設定済
- [ ] User-level subagent 9種が `~/.claude/agents/` に存在
- [ ] Project-level subagent 3種が `.claude/agents/` に存在
- [ ] memory/MEMORY.md + 各 agent.md が初期化済
- [ ] SessionStart hook が memory.md 自動注入することを確認
- [ ] CLAUDE.md v2 から戦国要素ゼロ
- [ ] legacy/ 削除済 (履歴は git log で追える)
- [ ] テストプロジェクトで「殿 → planner → spec 作成 → engineer dispatch → review → commit」のフルサイクル成功

## 10. 想定リスク

- **ユーザレベル agents が他プロジェクトに影響**: subagent description が雑だと意図しない自動起動。description は厳密に書く
- **memory.md 肥大化**: SessionStart で全 Read だと context 圧迫。size limit (例: 各 5KB) 推奨
- **planner の実装ミス**: planner が dispatch する仕組みが未テスト。Phase 8 で Hello World プロジェクトで検証必須
- **MIT 公開時の機密混入**: 殿名・秘鍵・API key が legacy に紛れる可能性。Phase 6 / 7 で grep + 手動確認

## 11. 殿アクション

殿が実施する点 (本仕様の他の部分は将軍が代行):

1. GitHub UI or `gh repo` で fork → rename `agent-orchestra-makoto-mizuno` (Phase 2)
2. main ブランチ保護設定の有効化 (Phase 2、GitHub UI でクリック)
3. CDP Chrome の手動 quit (Phase 1、auto mode で殿 process 殺さない安全策)
4. fork 後の git remote 切替 (`git remote set-url origin git@github.com:mizuno-makoto/agent-orchestra-makoto-mizuno.git` 等)

それ以外 (subagent 定義、CLAUDE.md 書換、hook、legacy 移動) は全て将軍代行。
