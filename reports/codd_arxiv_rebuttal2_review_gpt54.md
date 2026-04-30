# CPDD arXiv投稿戦略 再反論結果 — GPT-5.4 Pro Thinking (Heavy)

**評価日**: 2026-03-15
**評価者**: GPT-5.4 Pro Thinking (Heavy)

---

## 結論: 「arXiv先出しNO-GO」を撤回

| 投稿方法 | 判定 |
|---------|------|
| "vision / position paper" として出す | NO-GO寄り（制限対象になるリスク） |
| **"methodology / architecture research article" として出す** | **CONDITIONAL GO** |

---

## arXiv投稿の具体的ガイドライン

### タイトル

**避けるべき:**
- CPDD: A Vision for AI-Driven Development
- CPDD: A Paradigm Shift for Agentic Software Engineering

**推奨:**
- CPDD: A Conditioned Evidence Graph for Cross-Artifact Change Propagation in Software Systems
- Cross-Artifact Change Propagation via Conditioned Evidence Graphs

### 避けるべき表現

- "A Vision for …", "Toward …", "Position Paper", "Paradigm Shift"
- "Research Agenda", "We argue that …", "The future of SE is …"
- "This paper calls for…", "We hope to inspire…", "Future researchers should…"

### 使うべき表現

- "We define …", "We formalize …", "We present …"
- "We specify …", "We analyze …", "We illustrate with …"

### 最低限必要な構成

1. Introduction（具体例で痛点提示）
2. Problem Definition（入力・出力の定義）
3. Data Model（CEGのnode/edge/evidence/confidence/condition定義）
4. Change Calculus（change atom、transfer rule、停止条件、band分類）
5. Worked Example（1つのchangeがreq→config→code→testに伝播する端から端の例）
6. Implementation Sketch / Stage Plan
7. Analysis（termination、誤検知/見落としtrade-off、適用範囲）
8. Related Work
9. Limitations
10. Conclusion

### 実験なしで最低限あると強いもの（1つでOK）

- non-trivial worked example
- prototype screenshot / schema / code fragment
- toy corpusでのend-to-end walkthrough
- formal proposition（terminationなど）のdiscussion

---

## 非アカデミア著者の障壁

### endorsement問題（2026年1月以降厳格化）

- 初回投稿者はendorsement必要
- institutional emailだけでは不十分（2026年1月変更）
- 必要: 既存accepted authorship OR 既存arXiv著者からのpersonal endorsement

### 現実的な解決策

1. 原稿をresearch article体裁に仕上げる
2. 関連分野の既存arXiv著者にendorsement依頼
3. 可能なら既にarXiv論文を持つ人を共著者にする
4. または先に査読付きworkshop/NIERに出して実績を作る

---

## 参考リンク

- arXiv CS review/position paper運用変更: https://blog.arxiv.org/2025/10/31/
- arXiv投稿ガイドライン: https://info.arxiv.org/help/submit/index.html
- arXiv endorsementポリシー: https://info.arxiv.org/help/endorsement.html
- arXiv endorsement厳格化(2026-01): https://blog.arxiv.org/2026/01/21/
