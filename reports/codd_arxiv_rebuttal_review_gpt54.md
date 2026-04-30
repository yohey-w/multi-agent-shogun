# CPDD arXiv戦略 反論検証結果 — GPT-5.4 Pro Thinking (Heavy)

**評価日**: 2026-03-15
**評価者**: GPT-5.4 Pro Thinking (Heavy)
**入力**: Claude Opus 4.6の反論4本 + 2段構え戦略 + Abstract案

---

## 総合判定: 🟡 CONDITIONAL（変更なし）

ただし重要な戦略修正あり:
- **arXiv vision preprint を先に出す → NO-GO**
- **peer-reviewed vision venue を先に通してから arXiv → CONDITIONAL で成立**

---

## 反論の妥当性

| 反論 | 判定 | 要約 |
|------|------|------|
| A: ポジショニング変更 | ⚠️ 部分的有効 | vision paperなら成立するが、Code Digital Twin・SASE・Prometheusが既に近接。「空白を最初に見つけた」は言えない |
| B: 主体の逆転 | ❌ 無効 | SWE-agent、AutoCodeRover、Devin、SASEが既に提起済み。novelty claimには使えない |
| C: 2レイヤー統合 | ⚠️ 部分的有効 | 統合自体は新規ではない（MDE traceability、IBM ELM等）。新規性は「統合した上で何を推論可能にするか」 |
| D: 組織活動への汎用性 | ⚠️ 部分的有効 | Discussion末尾で触れる程度ならOK。title/abstract/contributionに入れるのは悪手 |

---

## 修正後の7観点再評価

| 観点 | 元 | 修正後 | 変化 |
|------|-----|--------|------|
| 新規性 | C | C | → |
| 技術的貢献 | D | **C** | ↑ |
| 問題の重要性 | A | A | → |
| 実現可能性 | C | C | → |
| 評価可能性 | C | C | → |
| 先行研究網羅性 | D | **C** | ↑ |
| 論文位置づけ | C | **B** | ↑ |

技術的貢献と先行研究が D→C に改善、論文位置づけが C→B に改善。

---

## 戦略の修正（重要）

### 元の戦略（Claude提案）
1. arXiv preprint (vision) → 旗を立てる
2. Layer 3 technical paper
3. ICSME 2026 Visions

### GPT-5.4の修正
1. **FSE IVR / ICSE NIER に先に出す**（peer-reviewed vision venue）
2. accept後にarXivに載せる
3. 並行してLayer 3 technical paper（ASE / ICSME research / SANER / SCAM）

**理由**: arXiv CSは2025年10月以降、review/position paperは事前の査読受理がないと却下されやすい運用に変更。

---

## 新たに指摘された競合研究

| 名称 | 内容 | CPDDとの関係 |
|------|------|-------------|
| Code Digital Twin | "living knowledge infrastructure" — artifact層とconceptual層をtraceable | 最も近い競合。AI向け構造化知識基盤を明示 |
| SASE | SE for Humans / SE for Agents の二重構造 | agentic SE方法論として直接競合 |
| Prometheus | repository全体をunified knowledge graphに変換 | KG統合アプローチとして競合 |

---

## Abstract修正指示

| 元の表現 | 修正後 |
|---------|--------|
| "demands the inverse" | "motivates stronger agent autonomy under human oversight" |
| "Unlike existing CIA approaches that operate within a single artifact layer" | "Existing CIA, traceability, and agentic-SE approaches typically emphasize subsets of lifecycle artifacts or rely on disconnected toolchains" |
| "across the entire V-model lifecycle" | "across requirements, design, code, configuration, tests, and selected operational assets" |
| "enabling AI agents to autonomously assess" | "to support agent-driven impact assessment under human oversight" |
| "the bottleneck is not model capability but the absence of structured knowledge" | "one major bottleneck is the absence of structured knowledge" |

---

## GPT-5.4が示した最重要の1文

> **CPDD is not the first vision of agentic software engineering; its specific claim is that agentic change reasoning requires a conditioned, evidence-grounded, cross-artifact knowledge substrate for propagating change under human oversight.**

この1文に沿って書き直せば「全部入り方法論」批判を避けられる。

---

## 参考文献（GPT-5.4が追加指摘）

1. Code Digital Twin — arXiv 2503.07967v4
2. SASE — agentic SE vision
3. Prometheus — unified knowledge graph for issue resolution
4. SWE-agent — arXiv 2405.15793
5. AutoCodeRover — autonomous program improvement
6. Jan Bosch — Towards AI-Driven Organizations (ACM)
7. arXiv CS moderation policy change (2025-10) — blog.arxiv.org
8. FSE 2026 IVR track — conf.researchr.org
