# CPDD arXiv論文化評価 — GPT-5.4 Pro Thinking (Heavy) 査読結果

**評価日**: 2026-03-15
**評価者**: GPT-5.4 Pro Thinking (Heavy)
**制約**: cpdd_architecture_v2.md と cpdd_research_report.md の原文未取得（会話中の設計要旨ベース）

---

## 総合判定: 🟡 CONDITIONAL

| 判定基準 | 結果 |
|---------|------|
| 会議メイン研究トラック | **Reject** |
| Vision / Position paper | **Major Revision** |
| Tool / System paper | **Not ready yet** |

---

## 7観点の採点

| 観点 | 評価 | 要約 |
|------|------|------|
| 1. 新規性 | **C** | 統合構想としてはあるが、個別技術が新規と言い切れない。CSDG, Ripple, DepsRAG等が近接 |
| 2. 技術的貢献 | **D** | "good systems architecture, weak technical core"。形式化も実証もない |
| 3. 問題の重要性 | **A** | enterprise CIAで設定/データ/暗黙知を含む問題設定は重要かつ独自性あり |
| 4. 実現可能性 | **C** | Stage 0-2は現実的。フルスタックは non-credible |
| 5. 評価可能性 | **C** | 評価可能だが1本の論文としては設計が甘い |
| 6. 先行研究網羅性 | **D** | CIA基礎(Arnold/Bohner/Lehnert/Li), CSDG, program slicing, architecture recovery, traceability recovery(LiSSA/TVR/TraceLLM), STC等が欠落 |
| 7. 論文位置づけ | **C** | cs.SE, vision paper推奨。ICSME 2026 Visions and Emerging Results が最適 |

---

## 致命的な指摘

### 1. "全部入り方法論"はトップ会議に通らない
> 1本の論文 = 1つの鋭い問い。CPDDは広すぎる。

### 2. 個別技術の新規性が弱い
- condition predicate付き伝播 → CSDG (conditional system dependence graph) が先行
- LLM-based CIA → Ripple (ICSE 2026) が近接
- KG+RAG → DepsRAG が先行
- bidirectional spec → Intent (Augment Code) が近接

### 3. 先行研究の穴が多い
**必須だが欠落している文献群:**
- CIA基礎: Arnold/Bohner, Lehnert survey, Li et al. survey, Rajlich Ripples/JRipples
- Program slicing: PDG/SDG/CSDG
- Architecture recovery: SARIF, Retriever, SemArc, ArchAgent
- KG for SE: systematic literature review
- Traceability recovery with LLM: LiSSA, TVR, TraceLLM
- Socio-technical congruence: Cataldo/Herbsleb

### 4. "taxonomy + heuristic rules + architecture diagram" は研究論文ではなく設計文書に見える

---

## 推奨アクション

### 最も論文にしやすい切り出し
> **"Resolution-aware Change Impact Analysis via Conditioned Evidence Graphs"**
> Layer 3（設定/DI/plugin/runtime resolution依存）に絞る

理由:
1. Ripple(intent-aware)とCSDG(config-aware)の間に明確な隙間がある
2. Spring/Guice/plugin systemsでbenchmark作成可能
3. 企業価値が最も高い（DI/config/profile/feature flagが一番痛い）

### 推奨ロードマップ
1. arXiv / ICSME Visions にvision paperとして再構成
2. 別論文としてLayer 3のresolution-aware CIAを切り出し
3. プロトタイプとbenchmarkを公開
4. ASE / ICSME main researchへ

### 推奨タイトル
**CPDD: A Vision for Evidence-Grounded Change Propagation across Requirements, Code, Configuration, and Tests**

### 必要な実験（最小限）
- Stage 1-2相当のプロトタイプ（Spring/Guice/plugin対象）
- 10-20 OSSシステムでbenchmark
- Baselines: static CIA, history-based CIA, config-aware CIA, Ripple
- Metrics: P/R/F1, Recall@k, band別precision, calibration
- Ablations: no conditions, no runtime, no history, no banding
- Human study: with/without CPDD

---

## 参考文献（GPT-5.4が指摘した必読文献）

1. Li et al. — code-based CIA survey (zhang-sai.github.io)
2. CSDG — configuration-aware CIA (Springer, 2019)
3. Ripple — intent-aware IA (ICSE 2026)
4. DepsRAG — LLM+KG dependency reasoning (arXiv 2024)
5. NARCIA — NL requirements CIA (ESEC/FSE 2015)
6. Retriever — unified architectural model (ScienceDirect 2024)
7. ArchAgent — multiview architecture recovery (arXiv 2024)
8. KG for SE — systematic literature review (ScienceDirect 2023)
9. LiSSA — generic traceability link recovery (ICSE 2025)
10. Cataldo/Herbsleb — socio-technical congruence (2008)
11. ICSME 2026 Visions track (conf.researchr.org)
