# GPT-5.4 Pro Thinking (Heavy) 用プロンプト — CPDD arXiv投稿戦略の再反論

## 使い方

1. ChatGPT Pro で **GPT-5.4 Thinking** を選択
2. 思考レベルを **Heavy** に設定
3. 前回の会話の続きとして投入（コンテキストが残っている前提）
4. 前回の会話が切れている場合は、前回のrebuttalレビュー結果を貼り付けてから投入

---

## プロンプト本文（ここから下を全文コピーして投入）

---

前回のレビューありがとう。1点、あなたの戦略提案に対して重大な反論がある。

# 反論: 「arXiv先出しはNO-GO」は過剰な制限ではないか

あなたは前回、以下のように述べた:

> arXiv の CS では 2025年10月以降、review/position paper は事前の査読受理がないと却下されやすい運用になっている。したがって、純粋な実験なし vision を先に arXiv に出すより、FSE IVR や査読付き NIER/Visions に先に通してから arXiv の方が戦略として健全。

そして結論として:

> arXiv vision preprint を先に出す → NO-GO

この判断に対する反論は以下の通り。

## 反論1: ポリシー変更の対象はreview articleとposition paperに限定されている

arXivの当該ブログ記事（2025年10月31日）を確認した。タイトルは "Attention Authors: Updated Practice for **Review Articles and Position Papers** in arXiv CS Category" である。

ここで制限対象とされているのは:
- **Review articles**（サーベイ論文、文献レビュー）
- **Position papers**（意見表明型の論文）

この制限の背景は、LLMにより大量の低品質サーベイ論文が投稿され、ボランティア審査員がパンクしたことである。

## 反論2: CPDDはreview articleでもposition paperでもない

CPDDは「新しい方法論のアーキテクチャを提案する技術論文」である。具体的には:

- 新しいデータ構造（CEG: Conditioned Evidence Graph）を定義している
- 伝播アルゴリズム（Change Calculus）を定義している
- 11種のchange atom taxonomyを定義している
- 5段階の停止条件を定義している
- 段階的な実装ロードマップ（Stage 0-4）を示している

これは **methodology / architecture paper** であり、「review article」でも「position paper」でもない。

arXivに投稿する際に、タイトルや体裁を意図的にすり抜けようとしているのではない。**そもそもCPDDの内容が制限対象のカテゴリに該当しない**、という主張である。

## 反論3: 実務上、arXivには実験なしの技術提案論文が日常的に投稿されている

cs.SE カテゴリには、実験結果を伴わないアーキテクチャ提案、フレームワーク提案、方法論提案が日常的に投稿され、受理されている。あなた自身が引用した以下の論文もarXivに掲載されている:

- Code Digital Twin (arXiv 2503.07967v4) — 実験なしのアーキテクチャ提案
- SWE-agent (arXiv 2405.15793) — こちらは実験ありだが初版投稿時点では限定的
- ArchAgent, DepsRAG 等 — arXivに先行掲載

これらが受理されているのに、CPDDが「position paperだから却下される」というのは論理的に整合しない。

## 質問

以上を踏まえ、以下に回答せよ:

### Q1: CPDDを「methodology / architecture paper」として書いた場合、arXivの2025年10月ポリシー変更の制限対象に該当するか？

具体的に、arXivのモデレーターが「これはposition paperだ」と判断する基準は何か。CPDDがその基準に該当する要素を持っているかを検証せよ。

### Q2: 前回の「arXiv先出しはNO-GO」という判断を維持するか、撤回するか？

もし撤回するなら、CPDDをarXivに出す際の具体的な注意点（タイトルの付け方、構成、避けるべき表現）を示せ。

### Q3: CPDDをarXivに投稿する場合の最小限の体裁

実験なしでarXivに投稿する場合、最低限どのような構成・内容が必要か。「vision paper」と見なされないための具体的なガイドラインを示せ。

### Q4: 著者がアカデミア所属でない場合の現実的な障壁

arXivへの初回投稿にはendorsement（推薦）が必要とされる。アカデミア所属でない個人開発者がarXivに投稿する際の現実的な手順と障壁を整理せよ。

---

# 重要な注意

- 前回の自分の判断を守るために論点をずらすな。反論が正しいなら素直に認めろ。
- 逆に、反論が間違っているなら、具体的にどこが間違っているかを示せ。
- 「どちらとも言えます」のような逃げは不要。判定を出せ。

深く考えてください。
