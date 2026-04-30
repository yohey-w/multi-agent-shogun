# GPT-5.4 Pro Thinking (Extra Heavy) 用プロンプト — CPDD arXiv論文化評価

## 使い方

1. ChatGPT Pro で **GPT-5.4 Thinking** を選択
2. 思考レベルを **Heavy** に設定
3. 以下のプロンプト本文を投入
4. **添付ファイル**: `cpdd_architecture_v2.md` と `cpdd_research_report.md` を添付する
5. 数分かかる可能性あり

---

## プロンプト本文（ここから下を全文コピーして投入）

---

あなたはソフトウェア工学（Software Engineering）分野のトップカンファレンス（ICSE, FSE, ASE, ISSTA）と主要ジャーナル（TSE, TOSEM, EMSE）で複数回採択経験のある査読者として振る舞ってください。同時に、LLM/AI for SE 分野（LLM4SE）の最新動向にも精通しています。

# タスク

添付した2つの文書は、**CPDD (Change-Propagation-Driven Development)** という新しいAI駆動開発方法論のアーキテクチャ設計です。

- `cpdd_architecture_v2.md` — 統合アーキテクチャ設計書（コアの技術設計）
- `cpdd_research_report.md` — 先行研究調査レポート（既存手法との比較）

**このアーキテクチャを arXiv 論文として発表する価値があるかどうかを、厳格に評価してください。**

「面白そうだね」という感想ではなく、トップ会議の査読者として**採択/不採択の判定とその根拠**を求めます。

---

# 評価観点

以下の7つの観点で評価してください。各観点について A/B/C/D/F の5段階評価と根拠を述べてください。

## 1. 新規性 (Novelty)

- この研究が主張する新規性は、先行研究に対して本当に新しいか？
- 具体的に: Change Impact Analysis (CIA) は1990年代から研究されている。CPDD が提案する「条件付き証拠グラフ (CEG) + Change Calculus + Multi-resolution Context」は、既存のCIA研究に対してどの程度の新規性があるか？
- 特に以下の既存研究との差分を厳密に検証せよ:
  - Ripple (Yadavally & Nguyen, ICSE 2026) — LLM-based change impact prediction
  - DepsRAG (arXiv 2024) — LLM+KG for dependency analysis
  - NARCIA (ESEC/FSE 2015) — NL requirements change impact
  - Temporal Graph + GNN approaches (ScienceDirect 2023)
  - Intent (Augment Code) — living specification bidirectional sync
  - BMAD-METHOD — multi-agent document-driven development
  - DOORS/Polarion/Jama — requirements traceability
  - TRLC+LOBSTER (BMW) — requirements-as-code

## 2. 技術的貢献 (Technical Contribution)

- 提案されている技術（CEG, Change Calculus, Evidence Ledger, Noisy-OR aggregation, 3-band classification, ambiguity-based context selection）は、個別に見て技術的に深いか？
- 「既存技術の組み合わせ」を超えた本質的な技術貢献はあるか？
- 特に: condition predicate付きエッジ、change atom taxonomy（11種）、5段階停止条件、transfer function設計は、形式的に新しいか？

## 3. 問題の重要性 (Problem Significance)

- 「エンタープライズシステムでの設定駆動・データ駆動・暗黙知を含む変更影響分析」は、SE研究コミュニティにとって重要な問題か？
- 産業界でのインパクトは？
- この問題設定自体に独自性はあるか？（つまり、問題の定義が新しいか？）

## 4. 実現可能性 (Feasibility)

- 提案されたアーキテクチャは実装可能か？
- 特に: Layer 3-5（Resolution, Behavioral, Governance）の検出精度の主張は妥当か？
- Stage 0→1→2→3→4 のロードマップは現実的か？
- 数千万ステップ級のシステムへのスケーラビリティに懸念はないか？

## 5. 評価可能性 (Evaluability)

- この提案を学術論文として評価する場合、どのような実験・評価が必要か？
- 評価なしで arXiv に出す場合（position paper / vision paper として）、どのベニュー（会場）が適切か？
- 評価ありで出す場合、最小限の実験として何が必要か？

## 6. 先行研究の網羅性 (Related Work Coverage)

- 添付の先行研究レポートは、この分野の主要研究を網羅しているか？
- 見落としている重要な研究はあるか？
- 特に、Change Impact Analysis、Program Slicing、Software Architecture Recovery、Knowledge Graph for SE の分野で欠けているものを指摘せよ。

## 7. 論文としての位置づけ (Paper Positioning)

- arXiv に出すとして、どのカテゴリ（cs.SE, cs.AI, cs.DB等）が適切か？
- 論文の種類として最適なのは何か？
  - (a) Full research paper（実験+評価必須）
  - (b) Vision / position paper（方向性提示）
  - (c) Tool / system paper（実装+デモ必須）
  - (d) Industry track paper（産業事例）
  - (e) Workshop paper（アイデア段階）
- 査読付き会議に投稿するなら、どのベニューが最適か？（ICSE, FSE, ASE, ICSME, SANER, ESEC, NL4SE workshop等）

---

# 追加で判断してほしいこと

## 8. 論文化する場合の構成案

もし論文化する価値があると判断した場合、以下を示せ:
- 推奨する論文タイトル（英語）
- Abstract案（200語以内）
- 論文の構成（Section構成）
- 主張すべきContribution（3点以内）
- 必要な実験・評価の設計

## 9. 論文化すべきでない場合の理由

もし論文化する価値がないと判断した場合:
- 具体的に何が足りないか
- どうすれば論文化可能になるか
- 代替の発表形態（ブログ、技術書、OSS公開等）のどれが最適か

## 10. 最も論文にしやすい部分の抽出

仮にアーキテクチャ全体ではなく一部を切り出すとしたら、どの部分が最も論文にしやすいか？
例:
- CEG（条件付き証拠グラフ）のデータモデルだけ
- Change Calculus（伝播エンジン）だけ
- Layer 3-5 の検出手法だけ
- Multi-resolution context engine だけ
- 産業事例（大里LMS適用）だけ

---

# 評価基準

最終的に、以下の3段階で判定せよ:

**🟢 GO**: arXiv投稿する価値がある。論文としての新規性・貢献が明確。
**🟡 CONDITIONAL**: 条件付きで価値がある。追加の実験/理論/比較が必要。何が必要かを具体的に示せ。
**🔴 NO-GO**: 現状では論文化は時期尚早。理由と代替策を示せ。

---

# 重要な注意

- お世辞は不要。厳しく評価してください。
- 「面白いアイデアですが...」のような婉曲表現は使わないでください。
- トップカンファレンスの査読者として、Accept/Reject/Major Revision/Minor Revision のどれに相当するかを明言してください。
- 著者の背景（エンタープライズSIer経験、マルチエージェントシステム運用経験）は評価に含めないでください。純粋に技術的内容で判断してください。

深く考えてください。表面的なレビューは不要です。
