<div align="center">

# multi-agent-shogun

**AIコーディング軍団統率システム — Multi-CLI対応**

*コマンド1つで、10体のAIエージェントが並列稼働 — **Claude Code / OpenAI Codex / GitHub Copilot / Kimi Code** 混成軍*

**Talk Coding — Vibe Codingではなく、スマホに話すだけでAIが実行**

[![GitHub Stars](https://img.shields.io/github/stars/yohey-w/multi-agent-shogun?style=social)](https://github.com/yohey-w/multi-agent-shogun)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![v3.5 Dynamic Model Routing](https://img.shields.io/badge/v3.5-Dynamic_Model_Routing-ff6600?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNiIgaGVpZ2h0PSIxNiI+PHRleHQgeD0iMCIgeT0iMTIiIGZvbnQtc2l6ZT0iMTIiPuKalTwvdGV4dD48L3N2Zz4=)](https://github.com/yohey-w/multi-agent-shogun)
[![Shell](https://img.shields.io/badge/Shell%2FBash-100%25-green)]()

[English](README.md) | [日本語](README_ja.md)

</div>

<p align="center">
  <img src="images/screenshots/hero/latest-translucent-20260210-190453.png" alt="将軍ペインでの最新半透過セッションキャプチャ" width="940">
</p>

<p align="center">
  <img src="images/screenshots/hero/latest-translucent-20260208-084602.png" alt="将軍ペインでの自然言語コマンド入力" width="420">
  <img src="images/company-creed-all-panes.png" alt="家老と足軽が全ペインで並列反応する様子" width="520">
</p>

<p align="center"><i>家老1体が足軽7体+軍師1体を統率 — 実際の稼働画面、モックデータなし</i></p>

---

## クイックスタート

**必要なもの:** tmux、bash 4+、以下のいずれか: [Claude Code](https://claude.ai/code) / Codex / Copilot / Kimi

```bash
git clone https://github.com/yohey-w/multi-agent-shogun
cd multi-agent-shogun
bash first_setup.sh          # 初回セットアップ: 設定・依存関係・MCP
bash shutsujin_departure.sh  # 全エージェント起動
```

将軍ペインに命令を入力：

> 「ユーザー認証の REST API を作って」

将軍が委譲 → 家老が分解 → 足軽7体が並列実行。
あとはダッシュボードを眺めるだけ。

> **もっと詳しく知りたい方へ:** 以降のセクションでアーキテクチャ・設定・メモリ設計・Multi-CLI対応を解説しています。

---

## これは何？

**multi-agent-shogun** は、複数のAIコーディングCLIインスタンスを同時に実行し、戦国時代の軍制のように統率するシステムです。**Claude Code**、**OpenAI Codex**、**GitHub Copilot**、**Kimi Code** の4CLIに対応。

**なぜ使うのか？**
- 1つの命令で、7体のAIワーカー+1体の軍師が並列で実行
- 待ち時間なし - タスクがバックグラウンドで実行中も次の命令を出せる
- AIがセッションを跨いであなたの好みを記憶（Memory MCP）
- ダッシュボードでリアルタイム進捗確認

```
      あなた（上様）
           │
           ▼ 命令を出す
    ┌─────────────┐
    │   SHOGUN    │  ← 命令を受け取り、即座に委譲
    └──────┬──────┘
           │ YAMLファイル + tmux
    ┌──────▼──────┐
    │    KARO     │  ← タスクをワーカーに分配
    └──────┬──────┘
           │
  ┌─┬─┬─┬─┴─┬─┬─┬────────┐
  │1│2│3│4│5│6│7│ GUNSHI │  ← 7体のワーカー + 1体の軍師
  └─┴─┴─┴─┴─┴─┴─┴────────┘
     ASHIGARU      軍師
```

---

## なぜ Shogun なのか？

多くのマルチエージェントフレームワークは、連携のためにAPIトークンを消費します。Shogunは違います。

| | Claude Code `Task` ツール | Claude Code Agent Teams | LangGraph | CrewAI | **multi-agent-shogun** |
|---|---|---|---|---|---|
| **アーキテクチャ** | 1プロセス内のサブエージェント | リード+チームメイト（JSONメールボックス） | グラフベースの状態機械 | ロールベースエージェント | tmux経由の階層構造 |
| **並列性** | 逐次実行（1つずつ） | 複数の独立セッション | 並列ノード（v0.2+） | 限定的 | **8体の独立エージェント** |
| **連携コスト** | TaskごとにAPIコール | 高い（各チームメイト=別コンテキスト） | API + インフラ（Postgres/Redis） | API + CrewAIプラットフォーム | **ゼロ**（YAML + tmux） |
| **Multi-CLI** | Claude Codeのみ | Claude Codeのみ | 任意のLLM API | 任意のLLM API | **4 CLI**（Claude/Codex/Copilot/Kimi） |
| **可観測性** | Claudeのログのみ | tmux分割ペインまたはインプロセス | LangSmith連携 | OpenTelemetry | **ライブtmuxペイン** + ダッシュボード |
| **スキル発見** | なし | なし | なし | なし | **ボトムアップ自動提案** |
| **セットアップ** | Claude Code内蔵 | 内蔵（実験的） | 重い（インフラ必要） | pip install | シェルスクリプト |

### 他のフレームワークとの違い

**連携コストゼロ** — エージェント間の通信はディスク上のYAMLファイル。APIコールは実際の作業にのみ使われ、オーケストレーションには使われません。8体のエージェントを動かしても、支払うのは8体分の作業コストだけです。

**完全な透明性** — すべてのエージェントが見えるtmuxペインで動作。すべての指示・報告・判断がプレーンなYAMLファイルで、読んで、diffして、バージョン管理できます。ブラックボックスなし。

**実戦で鍛えた階層構造** — 将軍→家老→足軽の指揮系統が設計レベルで衝突を防止：明確な責任分担、エージェントごとの専用ファイル、イベント駆動通信、ポーリングなし。

---

## なぜCLI（APIではなく）？

多くのAIコーディングツールはトークン従量課金。8体のOpus級エージェントをAPI経由で動かすと**$100+/時間**。CLI定額サブスクはこれを逆転させる：

| | API（従量課金） | CLI（定額制） |
|---|---|---|
| **8エージェント × Opus** | ~$100+/時間 | ~$200/月 |
| **コスト予測性** | 予測不能なスパイク | 月額固定 |
| **使用時の心理** | 1トークンが気になる | 使い放題 |
| **実験の余地** | 制約あり | 自由に投入 |

**「AIを使い倒す」思想** — 定額CLIサブスクなら、8体の足軽を気兼ねなく投入できる。1時間稼働でも24時間稼働でもコストは同じ。「まあまあ」と「徹底的に」の二択で悩む必要がない — エージェントを増やせばいい。

### Multi-CLI対応

将軍システムは特定ベンダーに依存しない。4つのCLIツールに対応し、それぞれの強みを活かす：

| CLI | 特徴 | デフォルトモデル |
|-----|------|-----------------|
| **Claude Code** | tmux統合の実績、Memory MCP、専用ファイルツール（Read/Write/Edit/Glob/Grep） | Claude Sonnet 4.6 |
| **OpenAI Codex** | サンドボックス実行、JSONL構造化出力、`codex exec` ヘッドレスモード | gpt-5.3-codex |
| **GitHub Copilot** | GitHub MCP組込、4種の特化エージェント（Explore/Task/Plan/Code-review）、`/delegate` | Claude Sonnet 4.6 |
| **Kimi Code** | 無料プランあり、多言語サポート | Kimi k2 |

統一ビルドシステムが共有テンプレートからCLI固有の指示書を自動生成：

```
instructions/
├── common/              # 共通ルール（全CLI共通）
├── cli_specific/        # CLI固有のツール説明
│   ├── claude_tools.md  # Claude Code ツール・機能
│   └── copilot_tools.md # GitHub Copilot CLI ツール・機能
└── roles/               # ロール定義（将軍、家老、足軽）
    ↓ ビルド
CLAUDE.md / AGENTS.md / copilot-instructions.md  ← CLI別に生成
```

ルールの変更は1箇所。全CLIに反映。同期ズレなし。

---

## ボトムアップスキル発見

他のフレームワークにはない機能です。

足軽がタスクを実行する中で、**再利用可能なパターンを自動的に発見**し、スキル候補として提案します。家老が提案を `dashboard.md` に集約し、殿（あなた）が正式なスキルに昇格させるか判断します。

```
足軽がタスクを完了
    ↓
気づき: 「このパターン、3つのプロジェクトで同じことをした」
    ↓
YAMLで報告:  skill_candidate:
                 found: true
                 name: "api-endpoint-scaffold"
                 reason: "3プロジェクトで同じRESTスキャフォールドパターンを使用"
    ↓
dashboard.md に掲載 → 殿が承認 → .claude/commands/ にスキル作成
    ↓
全エージェントが /api-endpoint-scaffold を呼び出し可能に
```

スキルは実際の作業から有機的に成長します — 既製のテンプレートライブラリからではなく。スキルセットは**あなた自身**のワークフローの反映になります。

---

## 🚀 クイックスタート

### 🪟 Windowsユーザー（最も一般的）

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **リポジトリをダウンロード**

[ZIPダウンロード](https://github.com/yohey-w/multi-agent-shogun/archive/refs/heads/main.zip) して `C:\tools\multi-agent-shogun` に展開

*または git を使用:* `git clone https://github.com/yohey-w/multi-agent-shogun.git C:\tools\multi-agent-shogun`

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **`install.bat` を実行**

右クリック→「管理者として実行」（WSL2が未インストールの場合）。WSL2 + Ubuntu をセットアップします。

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

🐧 **Ubuntu を開いて以下を実行**（初回のみ）

```bash
cd /mnt/c/tools/multi-agent-shogun
./first_setup.sh
```

</td>
</tr>
<tr>
<td>

**Step 4**

</td>
<td>

✅ **出陣！**

```bash
./shutsujin_departure.sh
```

</td>
</tr>
</table>

#### 🔑 初回のみ: 認証

`first_setup.sh` 完了後、一度だけ以下を実行して認証：

```bash
# 1. PATHの反映
source ~/.bashrc

# 2. OAuthログイン + Bypass Permissions承認（1コマンドで完了）
claude --dangerously-skip-permissions
#    → ブラウザが開く → Anthropicアカウントでログイン → CLIに戻る
#    → 「Bypass Permissions」の承認画面 → 「Yes, I accept」を選択（↓キーで2を選んでEnter）
#    → /exit で退出
```

認証情報は `~/.claude/` に保存され、以降は不要。

#### 📅 毎日の起動（初回セットアップ後）

**Ubuntuターミナル**（WSL）を開いて実行：

```bash
cd /mnt/c/tools/multi-agent-shogun
./shutsujin_departure.sh
```

### 📱 スマホからアクセス — 専用Androidアプリ（推奨）

<p align="center">
  <img src="android/screenshots/01_shogun_terminal.png" alt="将軍ターミナル" width="200">
  <img src="android/screenshots/02_agents_grid.png" alt="エージェント一覧" width="200">
  <img src="android/screenshots/03_dashboard.png" alt="ダッシュボード" width="200">
</p>

専用のAndroidアプリで10体のAIエージェントをスマホから監視・指揮できる。

| 機能 | 説明 |
|------|------|
| **将軍ターミナル** | SSHターミナル + 音声入力 + 特殊キーバー (C-c, C-b, Tab等) |
| **エージェント一覧** | 9ペイン同時監視。タップで全画面展開 + コマンド送信 |
| **ダッシュボード** | dashboard.md をレンダリング表示。表のテキストもコピー可 |
| **レートリミット** | エージェントタブ右下のボタンからClaude Max 5h/7d消費率をプログレスバーで確認 |
| **音声入力** | Google Speech APIによる日本語連続認識。キーボード音声入力より高精度 |
| **スクショ共有** | 共有メニューから画像をSFTP転送 |

> **Note:** 現在Androidのみ対応。iOS版は開発者にテスト端末がないため未対応。ニーズがあれば [Issue](https://github.com/yohey-w/multi-agent-shogun/issues) で教えてください。PRも歓迎！

#### セットアップ手順

**前提条件：**
- WSL2 (またはLinuxサーバー) で将軍システムが稼働中
- SSHサーバーが起動済み (`sudo service ssh start`)
- スマホとサーバーが同一ネットワーク上（LAN or [Tailscale](https://tailscale.com/)）

**手順：**

1. **APKをインストール**
   1. [`android/release/multi-agent-shogun.apk`](android/release/multi-agent-shogun.apk) をスマホにダウンロード（GitHub上のファイルを開いて「Download raw file」）
   2. ダウンロード完了の通知をタップ → 「インストール」
   3. 「提供元不明のアプリ」警告が出たら → 「設定」→ 該当ブラウザの「この提供元を許可」をON → 戻って「インストール」
   4. インストール完了 → 「開く」

2. **SSH接続情報を設定**（設定タブ）

   | 項目 | 入力例 | 説明 |
   |------|--------|------|
   | SSHホスト | `100.xxx.xxx.xxx` | サーバーのIP（Tailscale IPなど） |
   | SSHポート | `22` | 通常は22 |
   | SSHユーザー | `your_username` | SSH接続のユーザー名 |
   | SSH秘密鍵パス | `/data/data/.../id_ed25519` | スマホ上の秘密鍵パス（※1） |
   | SSHパスワード | `****` | 鍵がない場合はパスワード認証 |
   | プロジェクトパス | `/mnt/c/tools/multi-agent-shogun` | サーバー側のプロジェクトディレクトリ |
   | 将軍セッション名 | `shogun` | tmuxの将軍セッション名 |
   | エージェントセッション名 | `multiagent` | tmuxのエージェントセッション名 |

   ※1 秘密鍵はスマホに転送するか、パスワード認証を使用

3. **保存 → 将軍タブに切り替え** → 自動接続

**Tailscaleを使う場合（外出先からも接続可能）：**

```bash
# サーバー側（WSL2）
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscaled &
sudo tailscale up --authkey tskey-auth-XXXXXXXXXXXX
sudo service ssh start
```

スマホにもTailscaleアプリをインストールして同じアカウントでログイン。表示されるTailscale IPをアプリのSSHホストに入力。

**ntfy通知も併用する場合：**

[ntfyの設定セクション](#-8-スマホ通知ntfy)を参照。家老からの進捗通知をプッシュで受け取れる。

<details>
<summary>📟 <b>Termux方式（Androidアプリなし）</b>（クリックで展開）</summary>

Termuxを使ったSSH接続でも操作できる。専用アプリと比べて機能は限定的だが、追加のAPKインストールが不要。

**必要なもの（全部無料）：**

| 名前 | 一言で言うと | 役割 |
|------|------------|------|
| [Tailscale](https://tailscale.com/) | 外から自宅に届く道 | カフェからでもトイレからでも自宅PCに繋がる |
| SSH | その道を歩く足 | Tailscaleの道を通って自宅PCにログインする |
| [Termux](https://termux.dev/) | スマホの黒い画面 | SSHを使うために必要。スマホに入れるだけ |

**セットアップ：**

1. WSLとスマホの両方にTailscaleをインストール
2. WSL側（Auth key方式 — ブラウザ不要）：
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscaled &
   sudo tailscale up --authkey tskey-auth-XXXXXXXXXXXX
   sudo service ssh start
   ```
3. スマホのTermuxから：
   ```sh
   pkg update && pkg install openssh
   ssh あなたのユーザー名@あなたのTailscale IP
   css    # 将軍に繋がる
   ```
4. ＋ボタンで新しいウィンドウを開いて、部下の様子も見る：
   ```sh
   ssh あなたのユーザー名@あなたのTailscale IP
   csm    # 家老+足軽の9ペインが広がる
   ```

**切り方：** Termuxのウィンドウをスワイプで閉じるだけ。tmuxセッションは生き残る。AI部下は黙々と作業を続けている。

</details>

**音声入力：** Androidアプリの音声入力ボタンで喋れば、将軍が自然言語を理解して全軍に指示を出す。

**もっと簡単に：** ntfyを設定すると、プッシュ通知で進捗を受け取れます。

---

<details>
<summary>🐧 <b>Linux / Mac ユーザー</b>（クリックで展開）</summary>

### 初回セットアップ

```bash
# 1. リポジトリをクローン
git clone https://github.com/yohey-w/multi-agent-shogun.git ~/multi-agent-shogun
cd ~/multi-agent-shogun

# 2. スクリプトに実行権限を付与
chmod +x *.sh

# 3. 初回セットアップを実行
./first_setup.sh
```

### 毎日の起動

```bash
cd ~/multi-agent-shogun
./shutsujin_departure.sh
```

</details>

---

<details>
<summary>❓ <b>WSL2とは？なぜ必要？</b>（クリックで展開）</summary>

### WSL2について

**WSL2（Windows Subsystem for Linux）** は、Windows内でLinuxを実行できる機能です。このシステムは `tmux`（Linuxツール）を使って複数のAIエージェントを管理するため、WindowsではWSL2が必要です。

### WSL2がまだない場合

問題ありません！`install.bat` を実行すると：
1. WSL2がインストールされているかチェック（なければ自動インストール）
2. Ubuntuがインストールされているかチェック（なければ自動インストール）
3. 次のステップ（`first_setup.sh` の実行方法）を案内

**クイックインストールコマンド**（PowerShellを管理者として実行）：
```powershell
wsl --install
```

その後、コンピュータを再起動して `install.bat` を再実行してください。

</details>

---

<details>
<summary>📋 <b>スクリプトリファレンス</b>（クリックで展開）</summary>

| スクリプト | 用途 | 実行タイミング |
|-----------|------|---------------|
| `install.bat` | Windows: WSL2 + Ubuntu のセットアップ | 初回のみ |
| `first_setup.sh` | tmux、Node.js、Claude Code CLI のインストール + Memory MCP設定 | 初回のみ |
| `shutsujin_departure.sh` | tmuxセッション作成 + CLI起動 + 指示書読み込み + ntfyリスナー起動 | 毎日 |
| `scripts/switch_cli.sh` | エージェントのCLI/モデルをライブ切替（settings.yaml → /exit → 再起動） | 必要時 |

### `install.bat` が自動で行うこと：
- ✅ WSL2がインストールされているかチェック（未インストールなら案内）
- ✅ Ubuntuがインストールされているかチェック（未インストールなら案内）
- ✅ 次のステップ（`first_setup.sh` の実行方法）を案内

### `shutsujin_departure.sh` が行うこと：
- ✅ tmuxセッションを作成（shogun + multiagent）
- ✅ 全エージェントでClaude Codeを起動
- ✅ 各エージェントに指示書を自動読み込み
- ✅ キューファイルをリセットして新しい状態に
- ✅ ntfyリスナーを起動してスマホ通知を有効化（設定済みの場合）

**実行後、全エージェントが即座にコマンドを受け付ける準備完了！**

</details>

---

<details>
<summary>🔧 <b>必要環境（手動セットアップの場合）</b>（クリックで展開）</summary>

依存関係を手動でインストールする場合：

| 要件 | インストール方法 | 備考 |
|------|-----------------|------|
| WSL2 + Ubuntu | PowerShellで `wsl --install` | Windowsのみ |
| Ubuntuをデフォルトに設定 | `wsl --set-default Ubuntu` | スクリプトの動作に必要 |
| tmux | `sudo apt install tmux` | ターミナルマルチプレクサ |
| Node.js v20+ | `nvm install 20` | MCPサーバーに必要 |
| Claude Code CLI | `curl -fsSL https://claude.ai/install.sh \| bash` | Anthropic公式CLI（ネイティブ版を推奨。npm版は非推奨） |

</details>

---

### ✅ セットアップ後の状態

どちらのオプションでも、**10体のAIエージェント**が自動起動します：

| エージェント | 役割 | 数 |
|-------------|------|-----|
| 🏯 将軍（Shogun） | 総大将 - あなたの命令を受ける | 1 |
| 📋 家老（Karo） | 管理者 - タスク分配・簡易QC・ダッシュボード管理 | 1 |
| ⚔️ 足軽（Ashigaru） | ワーカー - 実装タスクを並列実行 | 7 |
| 🧠 軍師（Gunshi） | 参謀 - 分析・評価・設計など高度な思考タスク | 1 |

tmuxセッションが作成されます：
- `shogun` - ここに接続してコマンドを出す
- `multiagent` - 家老・足軽・軍師がバックグラウンドで稼働

---

## 📖 基本的な使い方

### Step 1: 将軍に接続

`shutsujin_departure.sh` 実行後、全エージェントが自動的に指示書を読み込み、作業準備完了となります。

新しいターミナルを開いて将軍に接続：

```bash
tmux attach-session -t shogun
```

### Step 2: 最初の命令を出す

将軍は既に初期化済み！そのまま命令を出せます：

```
JavaScriptフレームワーク上位5つを調査して比較表を作成せよ
```

将軍は：
1. タスクをYAMLファイルに書き込む
2. 家老（管理者）に通知
3. 即座にあなたに制御を返す（待つ必要なし！）

その間、家老はタスクを足軽ワーカーに分配し、並列実行します。

### Step 3: 進捗を確認

エディタで `dashboard.md` を開いてリアルタイム状況を確認：

```markdown
## 進行中
| ワーカー | タスク | 状態 |
|----------|--------|------|
| 足軽 1 | React調査 | 実行中 |
| 足軽 2 | Vue調査 | 実行中 |
| 足軽 3 | Angular調査 | 完了 |
```

### 詳細なフロー

```
あなた: 「トップ5のMCPサーバを調査して比較表を作成せよ」
```

将軍がタスクを `queue/shogun_to_karo.yaml` に書き込み、家老を起動。あなたには即座に制御が戻ります。

家老がタスクをサブタスクに分解：

| ワーカー | 割当内容 |
|----------|----------|
| 足軽 1 | Notion MCP調査 |
| 足軽 2 | GitHub MCP調査 |
| 足軽 3 | Playwright MCP調査 |
| 足軽 4 | Memory MCP調査 |
| 足軽 5 | Sequential Thinking MCP調査 |

5体の足軽が同時に調査開始。リアルタイムで作業を見ることができます。

<p align="center">
  <img src="images/company-creed-all-panes.png" alt="足軽がtmux全ペインで並列実行する様子" width="900">
</p>

結果は完了次第 `dashboard.md` に表示されます。

---

## ✨ 主な特徴

### ⚡ 1. 並列実行

1つの命令で最大8つの並列タスクを生成：

```
あなた: 「5つのMCPサーバを調査せよ」
→ 5体の足軽が同時に調査開始
→ 数時間ではなく数分で結果が出る
```

### 🔄 2. ノンブロッキングワークフロー

将軍は即座に委譲して、あなたに制御を返します：

```
あなた: 命令 → 将軍: 委譲 → あなた: 次の命令をすぐ出せる
                                    ↓
                    ワーカー: バックグラウンドで実行
                                    ↓
                    ダッシュボード: 結果を表示
```

長いタスクの完了を待つ必要はありません。

### 🧠 3. セッション間記憶（Memory MCP）

AIがあなたの好みを記憶します：

```
セッション1: 「シンプルな方法が好き」と伝える
            → Memory MCPに保存

セッション2: 起動時にAIがメモリを読み込む
            → 複雑な方法を提案しなくなる
```

### 📡 4. イベント駆動通信（ポーリングなし）

エージェント同士はYAMLファイルを書いて通信します — メモを渡すイメージ。**ポーリングなし、APIコールの浪費なし。**

```
家老が足軽3号を起こしたい場合:

Step 1: メッセージを書く            Step 2: エージェントを起こす
┌──────────────────────┐           ┌──────────────────────────┐
│ inbox_write.sh       │           │ inbox_watcher.sh         │
│                      │           │                          │
│ メッセージ全文を     │  ファイル │ ファイル変更を検知       │
│ ashigaru3.yaml に    │──変更────▶│ (inotifywait、ポーリング │
│ flock付きで書き込み  │           │  ではなくカーネルイベント)│
└──────────────────────┘           │                          │
                                   │ 起床方法:                │
                                   │  1. 自己監視（スキップ） │
                                   │  2. tmux send-keys       │
                                   │    （短いnudgeのみ）     │
                                   └──────────────────────────┘

Step 3: エージェントが自分のinboxを読む
┌──────────────────────────────────┐
│ 足軽3号が ashigaru3.yaml を読む  │
│ → 未読メッセージを発見           │
│ → 処理する                       │
│ → 既読にする                     │
└──────────────────────────────────┘
```

**起床の仕組み:**

| 優先順位 | 方式 | 何が起きるか | いつ使われるか |
|----------|------|-------------|---------------|
| 1番 | **自己監視** | エージェントが自分のinboxファイルを監視 — 自力で起床、nudge不要 | エージェント自身が `inotifywait` を実行中 |
| 2番 | **Stop Hook** | Claude Codeエージェントがターン終了時にinboxをチェック（`.claude/settings.json` Stop hook経由） | Claude Codeエージェントのみ |
| 3番 | **tmux send-keys** | `tmux send-keys` で短いnudgeを送信（テキストとEnterを分離送信、Codex CLI対応） | フォールバック — ASW Phase 2以上では無効 |

**Agent Self-Watch (ASW) フェーズ** — `tmux send-keys` nudgeの使用をどこまで抑制するかを制御:

| ASWフェーズ | nudge動作 | 配信方式 | 推奨場面 |
|------------|----------|---------|---------|
| **Phase 1** | 通常nudge有効 | self-watch + send-keys | 初期セットアップ、混在CLI環境 |
| **Phase 2** | **busy→抑止、idle→nudge** | busy: stop hookがターン終了時に配信。idle: nudge（不可避） | Claude Codeエージェント＋stop hook環境（推奨） |
| **Phase 3** | `FINAL_ESCALATION_ONLY` | 最終リカバリ時のみsend-keys | 完全に安定した環境 |

Phase 2はidleフラグファイル（`/tmp/shogun_idle_{agent}`）でbusy/idle状態を判定する。Stop hookがターン境界でフラグを作成/削除する。作業中のnudge割り込みを排除しつつ、idle時の起床は維持する。

> **なぜnudge完全撲滅できないのか？** Claude CodeのStop hookはターン終了時にしか発火しない。idleのエージェント（プロンプトで待機中）はターンが終了しないため、inboxチェックを発火させるhookがない。将来 `Notification` hookの `idle_prompt` タイプがブロック対応になるか、定期タイマーhookが追加されれば解決可能。

`config/settings.yaml` で設定:
```yaml
asw_phase: 2   # Claude Code環境では推奨
```

または `scripts/inbox_watcher.sh` の `ASW_PHASE` 変数を直接変更。変更後はinbox_watcherプロセスの再起動が必要。

**3段階エスカレーション（v3.2）** — エージェントが応答しない場合:

| フェーズ | タイミング | アクション |
|---------|----------|-----------|
| Phase 1 | 0-2分 | 標準nudge（`inbox3` テキスト + Enter） — *ASW Phase 2以上ではbusyエージェントはスキップ* |
| Phase 2 | 2-4分 | Escape×2 + C-c でカーソルリセット、その後nudge |
| Phase 3 | 4分以上 | `/clear` 送信でセッション強制リセット（5分間に最大1回） |

**設計のポイント:**
- **メッセージ内容はtmuxを経由しない** — 送るのは短い「メールが届いたよ」の通知だけ。中身はエージェントが自分でファイルを読む。これにより文字化けや配信ハングを根絶。
- **待機中のCPU使用率ゼロ** — `inotifywait` はカーネルイベントでブロック（ポーリングループではない）。メッセージ間のCPUは0%。
- **配信保証** — ファイル書き込みが成功すれば、メッセージは確実にそこにある。消失なし、リトライ不要。

### 📊 5. エージェント稼働確認

どのエージェントが稼働中か待機中か — コマンド1つで即座に確認：

```bash
# プロジェクトモード: タスク/inbox情報付きフルステータス
bash scripts/agent_status.sh

# スタンドアロンモード: 任意のtmuxセッションで動作
bash scripts/agent_status.sh --session mysession --lang en
```

**プロジェクトモード出力:**
```
Agent      CLI     Pane      Task ID                                    Status     Inbox
---------- ------- --------- ------------------------------------------ ---------- -----
karo       claude  待機中    ---                                        ---        0
ashigaru1  codex   稼働中    subtask_042a_research                      assigned   0
ashigaru2  codex   待機中    subtask_042b_review                        done       0
gunshi     claude  稼働中    subtask_042c_analysis                      assigned   0
```

**スタンドアロンモード出力**（プロジェクト設定不要）:
```
Pane                           State      Agent ID
------------------------------ ---------- ----------
multiagent:agents.0            IDLE       karo
multiagent:agents.1            BUSY       ashigaru1
multiagent:agents.8            BUSY       gunshi
```

判定は **Claude Code** と **Codex CLI** の両方に対応。各tmuxペインの末尾5行からCLI固有のプロンプト/スピナーパターンを検出。判定ロジックは `lib/agent_status.sh` に分離されており、自作スクリプトからも利用可能：

```bash
source lib/agent_status.sh
agent_is_busy_check "multiagent:agents.3" && echo "稼働中" || echo "待機中"
```

### 📸 6. スクリーンショット連携

VSCode拡張のClaude Codeはスクショを貼り付けて事象を説明できます。このCLIシステムでも同等の機能を実現：

```
# config/settings.yaml でスクショフォルダを設定
screenshot:
  path: "/mnt/c/Users/あなたの名前/Pictures/Screenshots"

# 将軍に伝えるだけ:
あなた: 「最新のスクショを見ろ」
あなた: 「スクショ2枚見ろ」
→ AIが即座にスクリーンショットを読み取って分析
```

**💡 Windowsのコツ:** `Win + Shift + S` でスクショが撮れます。保存先を `settings.yaml` のパスに合わせると、シームレスに連携できます。

こんな時に便利：
- UIのバグを視覚的に説明
- エラーメッセージを見せる
- 変更前後の状態を比較

### 📁 7. コンテキスト管理

効率的な知識共有のため、四層構造のコンテキストを採用：

| レイヤー | 場所 | 用途 |
|---------|------|------|
| Layer 1: Memory MCP | `memory/shogun_memory.jsonl` | プロジェクト横断・セッションを跨ぐ長期記憶 |
| Layer 2: Project | `config/projects.yaml`, `projects/<id>.yaml`, `context/{project}.md` | プロジェクト固有情報・技術知見 |
| Layer 3: YAML Queue | `queue/shogun_to_karo.yaml`, `queue/tasks/`, `queue/reports/` | タスク管理・指示と報告の正データ |
| Layer 4: Session | CLAUDE.md, instructions/*.md | 作業中コンテキスト（/clearで破棄） |

この設計により：
- どの足軽でも任意のプロジェクトを担当可能
- エージェント切り替え時もコンテキスト継続
- 関心の分離が明確
- セッション間の知識永続化

#### /clear プロトコル（コスト最適化）

長時間作業するとコンテキスト（Layer 4）が膨れ、APIコストが増大する。`/clear` でセッション記憶を消去すれば、コストがリセットされる。Layer 1〜3はファイルとして残るので失われない。

`/clear` 後の復帰コスト: **約6,800トークン**（v1から42%改善 — CLAUDE.mdのYAML化 + 英語のみの指示書でトークンコストを70%削減）

1. CLAUDE.md（自動読み込み）→ shogunシステムの一員と認識
2. `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` → 自分の番号を確認
3. Memory MCP 読み込み → 殿の好みを復元（~700トークン）
4. タスクYAML 読み込み → 次の仕事を確認（~800トークン）

「何を読ませないか」の設計がコスト削減に効いている。

#### 汎用コンテキストテンプレート

すべてのプロジェクトで同じ7セクション構成のテンプレートを使用：

| セクション | 目的 |
|-----------|------|
| What | プロジェクトの概要説明 |
| Why | 目的と成功の定義 |
| Who | 関係者と責任者 |
| Constraints | 期限、予算、制約 |
| Current State | 進捗、次のアクション、ブロッカー |
| Decisions | 決定事項と理由の記録 |
| Notes | 自由記述のメモ・気づき |

この統一フォーマットにより：
- どのエージェントでも素早くオンボーディング可能
- すべてのプロジェクトで一貫した情報管理
- 足軽間の作業引き継ぎが容易

### 📱 8. スマホ通知（ntfy）

スマホと将軍の間で双方向通信 — SSH不要、Tailscale不要、サーバ不要。

| 方向 | 仕組み |
|------|--------|
| **スマホ → 将軍** | ntfyアプリからメッセージを送信 → `ntfy_listener.sh` がストリーミングで受信 → 将軍が自動処理 |
| **家老 → スマホ（直接）** | 家老が `dashboard.md` を更新する際、`scripts/ntfy.sh` 経由で直接プッシュ通知を送信 — **将軍を経由しない**（将軍は人間との対話用、進捗報告用ではない） |

```
📱 あなた（ベッドから）       🏯 将軍
    │                          │
    │  "React 19を調査せよ"    │
    ├─────────────────────────►│
    │    (ntfyメッセージ)      │  → 家老に委譲 → 足軽が作業
    │                          │
    │  "✅ cmd_042 完了"       │
    │◄─────────────────────────┤
    │    (プッシュ通知)        │
```

**セットアップ：**
1. `config/settings.yaml` に `ntfy_topic: "shogun-yourname"` を追加
2. スマホに [ntfyアプリ](https://ntfy.sh) をインストールし、同じトピックをサブスクライブ
3. `shutsujin_departure.sh` がリスナーを自動起動 — 追加手順なし

**通知の例：**

| イベント | 通知内容 |
|----------|----------|
| コマンド完了 | `✅ cmd_042 complete — 5/5 subtasks done` |
| タスク失敗 | `❌ subtask_042c failed — API rate limit` |
| 対応要 | `🚨 Action needed: approve skill candidate` |
| ストリーク更新 | `🔥 3-day streak! 12/12 tasks today` |

無料、アカウント不要、サーバ管理不要。[ntfy.sh](https://ntfy.sh) — オープンソースのプッシュ通知サービスを利用。

> **⚠️ セキュリティ注意:** トピック名がそのままパスワードです。知っている人は誰でも通知を読んだり、将軍にメッセージを送れてしまいます。推測されにくい名前を選び、**スクリーンショットやブログ、GitHubコミットなどで公開しないでください**。

**動作確認:**

```bash
# テスト通知をスマホに送信
bash scripts/ntfy.sh "将軍システムからのテスト通知 🏯"
```

スマホに通知が届けば設定完了です。届かない場合:
- `config/settings.yaml` の `ntfy_topic` が設定されているか（空でないか、余分な引用符がないか）
- スマホのntfyアプリで**完全に同じトピック名**を購読しているか
- スマホがインターネットに接続されており、ntfyの通知が有効か

**スマホから将軍に指示を送る方法:**

1. スマホでntfyアプリを開く
2. 購読しているトピックをタップ
3. メッセージを入力（例: `React 19のベストプラクティスを調査して`）して送信
4. `ntfy_listener.sh` が受信 → `queue/ntfy_inbox.yaml` に書き込み → 将軍を起こす
5. 将軍がメッセージを読み、通常の家老→足軽パイプラインで処理

送信したテキストがそのままコマンドになります。将軍に話しかけるように書けばOK — 特別な構文は不要です。

**リスナーの手動起動**（`shutsujin_departure.sh` を使わない場合）:

```bash
# バックグラウンドでリスナーを起動
nohup bash scripts/ntfy_listener.sh &>/dev/null &

# 起動確認
pgrep -f ntfy_listener.sh

# ログを見ながら起動（フォアグラウンド）
bash scripts/ntfy_listener.sh
```

リスナーは接続が切れても自動的に再接続します。`shutsujin_departure.sh` で出陣すれば自動起動されるため、手動起動は出陣スクリプトを使わない場合のみ必要です。

**トラブルシューティング:**

| 症状 | 対処 |
|------|------|
| スマホに通知が来ない | `settings.yaml` とntfyアプリのトピック名が完全に一致しているか確認 |
| リスナーが起動しない | `bash scripts/ntfy_listener.sh` をフォアグラウンドで実行してエラーを確認 |
| スマホ→将軍が動かない | リスナーが稼働中か確認: `pgrep -f ntfy_listener.sh` |
| メッセージが将軍に届かない | `queue/ntfy_inbox.yaml` を確認 — メッセージがあれば将軍が処理中の可能性 |
| "ntfy_topic not configured" エラー | `config/settings.yaml` に `ntfy_topic: "your-topic"` を追加 |
| 通知が重複する | 再接続時の正常動作 — 将軍がメッセージIDで重複排除します |
| トピック名を変更したのに通知が来ない | リスナーの再起動が必要: `pkill -f ntfy_listener.sh && nohup bash scripts/ntfy_listener.sh &>/dev/null &` |

#### SayTask通知

行動心理学に基づくモチベーション通知：

- **ストリーク追跡**: `saytask/streaks.yaml` で連続完了日数をカウント — ストリーク維持が損失回避の心理を利用してモメンタムを持続
- **Eat the Frog** 🐸: その日の最も難しいタスクを「カエル」としてマーク。完了すると特別な祝福通知が送信される
- **日次進捗**: `12/12 tasks today` — 視覚的な完了フィードバックがArbeitslust効果（仕事の進捗による喜び）を強化

### 🖼️ 9. ペインボーダータスク表示

各tmuxペインのボーダーにエージェントの現在のタスクを表示：

```
┌ ashigaru1 Sonnet+T VF requirements ──┬ ashigaru3 Opus+T API research ──────┐
│                                      │                                     │
│  SayTask要件定義中                   │  REST APIパターン調査中             │
│                                      │                                     │
├ ashigaru2 Sonnet ───────────────────┼ ashigaru4 Spark DBスキーマ設計 ─────┤
│                                      │                                     │
│  （待機中 — 割当待ち）               │  データベーススキーマ設計中         │
│                                      │                                     │
└──────────────────────────────────────┴─────────────────────────────────────┘
```

- **作業中**: `ashigaru1 Sonnet+T VF requirements` — エージェント名、モデル（Thinkingインジケータ付き）、タスク概要
- **待機中**: `ashigaru2 Sonnet` — モデル名のみ、タスクなし
- **表示名**: Sonnet, Opus, Haiku, Codex, Spark — `+T` サフィックス = Extended Thinking有効
- 家老がタスク割当・完了時に自動更新
- 9ペインを一目見れば、誰が何をしているか即座にわかる

### 🔊 10. シャウトモード（戦国エコー）

足軽がタスクを完了すると、パーソナライズされた戦国風の叫びをtmuxペインに表示します — 部下が働いている実感を得られる。

```
┌ ashigaru1 Sonnet+T ─────────┬ ashigaru2 Sonnet+T ─────────┐
│                               │                               │
│  ⚔️ 足軽1号、任を果たし待機！ │  🔥 足軽2号、二番槍の意地！   │
│  八刃一志の志、胸に刻む！     │  八刃一志！共に城を落とせ！   │
│  ❯                            │  ❯                            │
└───────────────────────────────┴───────────────────────────────┘
```

**仕組み:**

家老がタスクYAMLに `echo_message` フィールドを記述。足軽は全作業完了後（レポート + inbox通知の後）、**最後のアクション**として `echo` を実行。メッセージは `❯` プロンプト直上に残る。

```yaml
# タスクYAML（家老が記述）
task:
  task_id: subtask_001
  description: "比較表を作成"
  echo_message: "🔥 足軽1号、先陣を切って参る！八刃一志！"
```

**シャウトモードがデフォルト。** 無効にする場合（echoのAPIトークン節約）:

```bash
./shutsujin_departure.sh --silent    # 戦国エコーなし
./shutsujin_departure.sh             # デフォルト: シャウトモード（戦国エコー有効）
```

サイレントモードは `DISPLAY_MODE=silent` をtmux環境変数に設定。家老がタスクYAML作成時にこれを確認し、`echo_message` フィールドを省略する。

---

## 🗣️ SayTask — タスク管理が嫌いな人のためのタスク管理

### SayTaskとは？

**タスク管理が嫌いな人のためのタスク管理。スマホに話しかけるだけ。**

**Talk Coding — Vibe Codingではない。** タスクを話すだけで、AIが整理する。入力なし、アプリを開かない、摩擦ゼロ。

- **ターゲット**: Todoistをインストールしたけど3日で開かなくなった人
- あなたの敵は他のアプリじゃない。何もしないこと。競合は他の生産性ツールではなく、無行動
- UIゼロ。入力ゼロ。アプリを開く動作ゼロ。ただ話すだけ

> *「あなたの敵は他のアプリじゃない。何もしないことだ。」*

### 仕組み

1. [ntfyアプリ](https://ntfy.sh)をインストール（無料、アカウント不要）
2. スマホに話しかける: *「歯医者 明日」*、*「請求書 金曜まで」*
3. AIが自動整理 → 朝に通知: *「今日の予定です」*

```
 🗣️ 「牛乳買う、歯医者 明日、請求書 金曜まで」
       │
       ▼
 ┌──────────────────┐
 │  ntfy → 将軍     │  AIが自動分類、日付解析、優先度設定
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐
 │   tasks.yaml     │  構造化ストレージ（ローカル、端末外に出ない）
 └────────┬─────────┘
          │
          ▼
 📱 朝の通知:
    「今日: 🐸 請求書期限 · 🦷 歯医者3時 · 🛒 牛乳買う」
```

### 変更前／変更後

| 変更前（v1） | 変更後（v2） |
|:-----------:|:----------:|
| ![タスク一覧 v1](images/screenshots/masked/ntfy_tasklist_v1_before.jpg) | ![タスク一覧 v2](images/screenshots/masked/ntfy_tasklist_v2_aligned.jpg) |
| 生のタスクダンプ | きれいに整理された日次サマリ |

> *注: スクリーンショットに表示されているトピック名は例です。自分専用のトピック名を使用してください。*

### ユースケース

- 🛏️ **ベッドの中**: *「明日レポート提出しないと」* — 忘れる前にキャプチャ、ノート探さなくていい
- 🚗 **運転中**: *「クライアントAの見積もり忘れないで」* — ハンズフリー、前を見たまま
- 💻 **仕事中**: *「あ、牛乳買わないと」* — 即座にダンプしてフローに戻る
- 🌅 **起床時**: 今日のタスクが既に通知で待っている — アプリを開かない、受信トレイ確認不要
- 🐸 **Eat the Frog**: AIが毎朝一番大変なタスクを選ぶ — 無視してもいいし、最初に倒してもいい

### FAQ

**Q: 他のタスクアプリと何が違う？**
A: アプリを開かない。ただ話すだけ。摩擦ゼロ。多くのタスクアプリは、人々が開かなくなるから失敗する。SayTaskはそのステップ自体を取り除いた。

**Q: Shogunシステム全体なしでSayTaskだけ使える？**
A: SayTaskはShogunの機能の一部。Shogunはスタンドアロンのマルチエージェント開発プラットフォームとしても機能する — 1つのシステムで両方の機能が手に入る。

**Q: 🐸 Frogって何？**
A: 毎朝、AIがあなたの一番大変なタスクを選ぶ — 避けたいやつ。最初に倒す（「Eat the Frog」方式）か無視するか。あなた次第。

**Q: 無料？**
A: すべて無料でオープンソース。ntfyも無料。アカウント不要、サーバ不要、サブスクリプション不要。

**Q: データはどこに保存される？**
A: ローカルのYAMLファイル。クラウドには何も送信されない。タスクは端末の外に出ない。

**Q: 「仕事のあれ」みたいに曖昧なことを言ったら？**
A: AIがベストを尽くして分類・スケジュールする。後で修正もできる — でもポイントは、忘れる前に思考をキャプチャすること。

### SayTask vs cmdパイプライン

将軍システムには2つの補完的なタスクシステムがある：

| 機能 | SayTask（音声レイヤー） | cmdパイプライン（AI実行） |
|---|:-:|:-:|
| 音声入力 → タスク作成 | ✅ | — |
| 朝の通知ダイジェスト | ✅ | — |
| Eat the Frog 🐸 選定 | ✅ | — |
| ストリーク追跡 | ✅ | ✅ |
| AI実行タスク（複数ステップ） | — | ✅ |
| 8エージェント並列実行 | — | ✅ |

SayTaskは個人の生産性を担当（キャプチャ → スケジュール → リマインド）。cmdパイプラインは複雑な作業を担当（リサーチ、コード、複数ステップのタスク）。両者はストリーク追跡を共有し、どちらのタスクを完了してもデイリーストリークにカウントされる。

---

## 🧠 モデル設定

| エージェント | モデル | 思考モード | 役割 |
|-------------|--------|----------|------|
| 将軍 | Opus | **有効（high）** | 殿の参謀。`--shogun-no-thinking` で中継専用モードに |
| 家老 | Sonnet | 有効 | タスク分配・簡易QC・ダッシュボード管理 |
| 軍師 | Opus | 有効 | 深い分析・設計レビュー・アーキテクチャ評価 |
| 足軽1-7 | Sonnet 4.6 | 有効 | 実装：コード・リサーチ・ファイル操作 |

**Thinking制御**: `config/settings.yaml` でエージェントごとに `thinking: true/false` を設定可能。`thinking: false` の場合、`MAX_THINKING_TOKENS=0` で起動しExtended Thinkingを無効化。ペインボーダーにはThinking有効時に `+T` サフィックスが表示される（例: `Sonnet+T`、`Opus+T`）。

**ライブモデル切替**: `/shogun-model-switch` スキルで、システム全体を再起動せずに任意エージェントのCLI種別・モデル・Thinking設定を変更可能。詳細はスキルセクション参照。

**認知的複雑さ**でのルーティングは2段階：**エージェントルーティング**（足軽はL1-L3、軍師はL4-L6）と **足軽内のモデルルーティング**（`capability_tiers` でBloomレベルに応じて最適モデルを選択。下記「動的モデルルーティング」参照）。

### Bloom's Taxonomy → エージェントルーティング

タスクはBloom's Taxonomy（ブルームの分類法）に基づいて分類し、最適な**エージェント**にルーティングします：

| レベル | カテゴリ | 内容 | ルーティング先 |
|--------|----------|------|---------------|
| L1 | 記憶 | 事実の想起、コピー、一覧化 | **足軽** |
| L2 | 理解 | 説明、要約、言い換え | **足軽** |
| L3 | 応用 | 手順の実行、既知パターンの実装 | **足軽** |
| L4 | 分析 | 比較、調査、構造の分解 | **軍師** |
| L5 | 評価 | 判断、批評、推奨 | **軍師** |
| L6 | 創造 | 設計、構築、新しいソリューションの統合 | **軍師** |

家老が各サブタスクにBloomレベルを付与し、適切なエージェントにルーティング。L1-L3は足軽に並列分配、L4-L6は軍師へ。簡単なL4タスク（小規模なコードレビュー等）は、家老の判断で足軽に回すこともある。

### タスク依存関係（blockedBy）

タスクは `blockedBy` を使って他タスクへの依存を宣言できます：

```yaml
# queue/tasks/ashigaru2.yaml
task:
  task_id: subtask_010b
  blockedBy: ["subtask_010a"]  # 足軽1のタスク完了を待つ
  description: "subtask_010aで構築したAPIクライアントを統合"
```

ブロック元のタスクが完了すると、家老が自動的に依存タスクのブロックを解除し、空いている足軽に割り当てます。これにより待機時間が削減され、依存タスクの効率的なパイプライン処理が可能になります。

### 動的モデルルーティング（capability_tiers）

エージェント単位のルーティングに加え、**足軽階層内でのモデルレベルルーティング**も設定できます。`config/settings.yaml` に `capability_tiers` テーブルを定義し、各モデルのBloom上限を指定します：

```yaml
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3       # L1–L3: 高速・大量処理タスク
    cost_group: chatgpt_pro
  gpt-5.3-codex:
    max_bloom: 4       # L1–L4: + 分析・デバッグ
    cost_group: chatgpt_pro
  claude-sonnet-4-6:
    max_bloom: 5       # L1–L5: + 設計評価
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6       # L1–L6: + 新規アーキテクチャ・戦略
    cost_group: claude_max
```

`cost_group` フィールドで各モデルをサブスクリプションプランに紐付け、契約外のモデルへのルーティングを防止します。

設定を支援する2つの組み込みスキルがあります：

| スキル | 用途 |
|--------|------|
| `/shogun-model-list` | 全モデル × サブスクリプション × Bloom上限の参照テーブル |
| `/shogun-bloom-config` | 対話式: 2つの質問に答えるだけで最適な `capability_tiers` YAMLを生成 |

セットアップ後に `/shogun-bloom-config` を実行して、最適な `capability_tiers` 設定を生成してください。

---

## 🧭 核心思想（Philosophy）

> **「脳死で依頼をこなすな。最速×最高のアウトプットを常に念頭に置け。」**

将軍システムは5つの核心原則に基づいて設計されている：

| 原則 | 説明 |
|------|------|
| **自律陣形設計** | テンプレートではなく、タスクの複雑さに応じて陣形を設計 |
| **並列化** | サブエージェントを活用し、単一障害点を作らない |
| **リサーチファースト** | 判断の前にエビデンスを探す |
| **継続的学習** | モデルの知識カットオフだけに頼らない |
| **三角測量** | 複数視点からのリサーチと統合的オーソライズ |

詳細: **[docs/philosophy.md](docs/philosophy.md)**

---

## 🎯 設計思想

### なぜ階層構造（将軍→家老→足軽）なのか

1. **即座の応答**: 将軍は即座に委譲し、あなたに制御を返す
2. **並列実行**: 家老が複数の足軽に同時分配
3. **単一責任**: 各役割が明確に分離され、混乱しない
4. **スケーラビリティ**: 足軽を増やしても構造が崩れない
5. **障害分離**: 1体の足軽が失敗しても他に影響しない
6. **人間への報告一元化**: 将軍だけが人間とやり取りするため、情報が整理される

### なぜメールボックスシステムなのか

直接メッセージではなく、なぜファイル経由なのか？

| 直接メッセージの問題 | メールボックスの解決策 |
|---------------------|----------------------|
| エージェントがクラッシュ → メッセージ消失 | YAMLファイルは再起動後も残る |
| ポーリングでAPIコールを浪費 | `inotifywait` はイベント駆動（待機中CPU 0%） |
| エージェント同士が割り込み合う | エージェントごとに専用inboxファイル — 干渉なし |
| デバッグが困難 | `.yaml` ファイルを開けばメッセージ履歴が見える |
| 同時書き込みでデータ破損 | `flock`（排他ロック）が自動で直列化 |
| 配信障害（文字化け、ハング） | メッセージ内容はファイルに保存 — tmux経由は短い「メールが届いたよ」通知だけ |

### エージェント識別（@agent_id）

各ペインに `@agent_id` というtmuxユーザーオプションを設定（例: `karo`, `ashigaru1`）。`pane_index` はペイン再配置でズレるが、`@agent_id` は `shutsujin_departure.sh` が起動時に固定設定するため変わらない。

エージェントの自己識別:
```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```
`-t "$TMUX_PANE"` が必須。省略するとアクティブペイン（操作中のペイン）の値が返り、誤認識の原因になる。

モデル名は `@model_name`、現在のタスクの要約は `@current_task` として保存され、いずれも `pane-border-format` で常時表示されます。Claude Codeがペインタイトルを上書きしても、これらのユーザーオプションは消えません。

### なぜ dashboard.md は家老のみが更新するのか

1. **単一更新者**: 競合を防ぐため、更新責任者を1人に限定
2. **情報集約**: 家老は全足軽の報告を受ける立場なので全体像を把握
3. **一貫性**: すべての更新が1つの品質ゲートを通過
4. **割り込み防止**: 将軍が更新すると、殿の入力中に割り込む恐れあり

---

## 🛠️ スキル

初期状態ではスキルはありません。
運用中にダッシュボード（dashboard.md）の「スキル化候補」から承認して増やしていきます。

スキルは `/スキル名` で呼び出し可能。将軍に「/スキル名 を実行」と伝えるだけ。

### 同梱スキル（リポジトリにコミット済み）

`skills/` ディレクトリにスキルが同梱されています。どのユーザにも有用なユーティリティです：

| スキル | 説明 |
|--------|------|
| `/skill-creator` | スキル作成のテンプレート・ガイド |
| `/shogun-agent-status` | 全エージェントの稼働/待機状態をタスク・inbox情報付きで表示 |
| `/shogun-model-list` | 全CLIツール × モデル × サブスクリプション × Bloom上限の参照テーブル |
| `/shogun-bloom-config` | 対話式設定: 2つの質問に答えるだけで `capability_tiers` YAMLを生成 |
| `/shogun-model-switch` | ライブCLI/モデル切替: settings.yaml更新 → `/exit` → 正しいフラグで再起動。Thinking ON/OFF制御も対応 |
| `/shogun-readme-sync` | README.md と README_ja.md の同期 |

システムの設定・運用を支援するスキルです。個人のワークフロースキルはボトムアップ発見プロセスで有機的に成長します。

### スキルの思想

**1. 個人スキルはコミット対象外**

`.claude/commands/` 配下のスキルはリポジトリにコミットしない設計。理由：
- 各ユーザの業務・ワークフローは異なる
- 汎用的なスキルを押し付けるのではなく、ユーザが自分に必要なスキルを育てていく

**2. スキル取得の手順**

```
足軽が作業中にパターンを発見
    ↓
dashboard.md の「スキル化候補」に上がる
    ↓
殿（あなた）が内容を確認
    ↓
承認すれば家老に指示してスキルを作成
```

スキルはユーザ主導で増やすもの。自動で増えると管理不能になるため、「これは便利」と判断したものだけを残す。

---

## 🔌 MCPセットアップガイド

MCP（Model Context Protocol）サーバはClaudeの機能を拡張します。セットアップ方法：

### MCPとは？

MCPサーバはClaudeに外部ツールへのアクセスを提供します：
- **Notion MCP** → Notionページの読み書き
- **GitHub MCP** → PR作成、Issue管理
- **Memory MCP** → セッション間で記憶を保持

### MCPサーバのインストール

以下のコマンドでMCPサーバを追加：

```bash
# 1. Notion - Notionワークスペースに接続
claude mcp add notion -e NOTION_TOKEN=your_token_here -- npx -y @notionhq/notion-mcp-server

# 2. Playwright - ブラウザ自動化
claude mcp add playwright -- npx @playwright/mcp@latest
# 注意: 先に `npx playwright install chromium` を実行してください

# 3. GitHub - リポジトリ操作
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat_here -- npx -y @modelcontextprotocol/server-github

# 4. Sequential Thinking - 複雑な問題を段階的に思考
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# 5. Memory - セッション間の長期記憶（推奨！）
# ✅ first_setup.sh で自動設定済み
# 手動で再設定する場合:
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/shogun_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory
```

### インストール確認

```bash
claude mcp list
```

全サーバが「Connected」ステータスで表示されるはずです。

---

## 🌍 実用例

### 例1: 調査タスク

```
あなた: 「AIコーディングアシスタント上位5つを調査して比較せよ」

実行される処理:
1. 将軍が家老に委譲
2. 家老が割り当て:
   - 足軽1: GitHub Copilotを調査
   - 足軽2: Cursorを調査
   - 足軽3: Claude Codeを調査
   - 足軽4: Codeiumを調査
   - 足軽5: Amazon CodeWhispererを調査
3. 5体が同時に調査
4. 結果がdashboard.mdに集約
```

### 例2: PoC準備

```
あなた: 「このNotionページのプロジェクトでPoC準備: [URL]」

実行される処理:
1. 家老がMCP経由でNotionコンテンツを取得
2. 足軽2: 確認すべき項目をリスト化
3. 足軽3: 技術的な実現可能性を調査
4. 足軽4: PoC計画書を作成
5. 全結果がdashboard.mdに集約、会議の準備完了
```

---

## ⚙️ 設定

### 言語設定

```yaml
# config/settings.yaml
language: ja   # 日本語のみ
language: en   # 日本語 + 英訳併記
```

### スクリーンショット連携

```yaml
# config/settings.yaml
screenshot:
  path: "/mnt/c/Users/あなたの名前/Pictures/Screenshots"
```

将軍に「最新のスクショを見ろ」と伝えるだけで、スクリーンキャプチャを読み取って分析します。（Windowsでは `Win+Shift+S`）

### ntfy（スマホ通知）

```yaml
# config/settings.yaml
ntfy_topic: "shogun-yourname"
```

スマホの [ntfyアプリ](https://ntfy.sh) で同じトピックをサブスクライブしてください。リスナーは `shutsujin_departure.sh` で自動起動します。

#### ntfy認証（セルフホストサーバ向け）

公開の ntfy.sh インスタンスは**認証不要**です。上記の設定だけで動作します。

セルフホストのntfyサーバでアクセス制御を有効にしている場合、認証を設定します：

```bash
# 1. サンプル設定をコピー
cp config/ntfy_auth.env.sample config/ntfy_auth.env

# 2. 認証情報を記入（いずれかの方式を選択）
```

| 方式 | 設定 | 用途 |
|------|------|------|
| **Bearerトークン**（推奨） | `NTFY_TOKEN=tk_your_token_here` | トークン認証のセルフホストntfy（`ntfy token add <user>` で生成） |
| **Basic認証** | `NTFY_USER=ユーザー名` + `NTFY_PASS=パスワード` | ユーザー/パスワード認証のセルフホストntfy |
| **認証なし**（デフォルト） | ファイルを空のままにするか作成しない | 公開の ntfy.sh — 認証不要 |

優先順位: トークン > Basic認証 > なし。どちらも設定されていなければ、認証ヘッダは送信されません（後方互換）。

`config/ntfy_auth.env` はgit追跡対象外です。詳細は `config/ntfy_auth.env.sample` を参照。

---

## 🛠️ 上級者向け

<details>
<summary><b>スクリプトアーキテクチャ</b>（クリックで展開）</summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                      初回セットアップ（1回だけ実行）                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  install.bat (Windows)                                              │
│      │                                                              │
│      ├── WSL2のチェック/インストール案内                              │
│      └── Ubuntuのチェック/インストール案内                            │
│                                                                     │
│  first_setup.sh (Ubuntu/WSLで手動実行)                               │
│      │                                                              │
│      ├── tmuxのチェック/インストール                                  │
│      ├── Node.js v20+のチェック/インストール (nvm経由)                │
│      ├── Claude Code CLIのチェック/インストール（ネイティブ版）       │
│      │       ※ npm版検出時はネイティブ版への移行を提案                │
│      └── Memory MCPサーバー設定                                      │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                      毎日の起動（毎日実行）                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  shutsujin_departure.sh                                             │
│      │                                                              │
│      ├──▶ tmuxセッションを作成                                       │
│      │         • "shogun"セッション（1ペイン）                        │
│      │         • "multiagent"セッション（9ペイン、3x3グリッド）        │
│      │                                                              │
│      ├──▶ キューファイルとダッシュボードをリセット                     │
│      │                                                              │
│      └──▶ 全エージェントでClaude Codeを起動                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

</details>

<details>
<summary><b>shutsujin_departure.sh オプション</b>（クリックで展開）</summary>

```bash
# デフォルト: フル起動（tmuxセッション + Claude Code起動）
./shutsujin_departure.sh

# セッションセットアップのみ（Claude Code起動なし）
./shutsujin_departure.sh -s
./shutsujin_departure.sh --setup-only

# タスクキューをクリア（指令履歴は保持）
./shutsujin_departure.sh -c
./shutsujin_departure.sh --clean

# 決戦の陣: 全足軽をOpusで起動（最大能力・高コスト）
./shutsujin_departure.sh -k
./shutsujin_departure.sh --kessen

# サイレントモード: 戦国エコーを無効化（echoのAPIトークン節約）
./shutsujin_departure.sh -S
./shutsujin_departure.sh --silent

# フル起動 + Windows Terminalタブを開く
./shutsujin_departure.sh -t
./shutsujin_departure.sh --terminal

# 将軍中継専用モード: 将軍のThinkingを無効化（コスト節約）
./shutsujin_departure.sh --shogun-no-thinking

# ヘルプを表示
./shutsujin_departure.sh -h
./shutsujin_departure.sh --help
```

</details>

<details>
<summary><b>よく使うワークフロー</b>（クリックで展開）</summary>

**通常の毎日の使用：**
```bash
./shutsujin_departure.sh          # 全て起動
tmux attach-session -t shogun     # 接続してコマンドを出す
```

**デバッグモード（手動制御）：**
```bash
./shutsujin_departure.sh -s       # セッションのみ作成

# 特定のエージェントでClaude Codeを手動起動
tmux send-keys -t shogun:0 'claude --dangerously-skip-permissions' Enter
tmux send-keys -t multiagent:0.0 'claude --dangerously-skip-permissions' Enter
```

**クラッシュ後の再起動：**
```bash
# 既存セッションを終了
tmux kill-session -t shogun
tmux kill-session -t multiagent

# 新しく起動
./shutsujin_departure.sh
```

</details>

<details>
<summary><b>便利なエイリアス</b>（クリックで展開）</summary>

`first_setup.sh` を実行すると、以下のエイリアスが `~/.bashrc` に自動追加されます：

```bash
alias csst='cd /mnt/c/tools/multi-agent-shogun && ./shutsujin_departure.sh'
alias css='tmux attach-session -t shogun'      # 将軍ウィンドウの起動
alias csm='tmux attach-session -t multiagent'  # 家老・足軽ウィンドウの起動
```

※ エイリアスを反映するには `source ~/.bashrc` を実行するか、PowerShellで `wsl --shutdown` してからターミナルを開き直してください。

</details>

---

## 📁 ファイル構成

<details>
<summary><b>クリックでファイル構成を展開</b></summary>

```
multi-agent-shogun/
│
│  ┌─────────────────── セットアップスクリプト ───────────────────┐
├── install.bat               # Windows: 初回セットアップ
├── first_setup.sh            # Ubuntu/Mac: 初回セットアップ
├── shutsujin_departure.sh    # 毎日の起動（指示書自動読み込み）
│  └────────────────────────────────────────────────────────────┘
│
├── instructions/             # エージェント指示書
│   ├── shogun.md             # 将軍の指示書
│   ├── karo.md               # 家老の指示書
│   ├── ashigaru.md           # 足軽の指示書
│   ├── gunshi.md             # 軍師の指示書
│   └── cli_specific/         # CLI固有のツール説明
│       ├── claude_tools.md   # Claude Code ツール・機能
│       └── copilot_tools.md  # GitHub Copilot CLI ツール・機能
│
├── lib/
│   ├── agent_status.sh       # 共有 稼働/待機 判定（Claude Code + Codex）
│   ├── cli_adapter.sh        # Multi-CLIアダプタ（Claude/Codex/Copilot/Kimi）
│   └── ntfy_auth.sh          # ntfy認証ヘルパー
│
├── scripts/                  # ユーティリティスクリプト
│   ├── agent_status.sh       # 全エージェントの稼働/待機状態を表示
│   ├── inbox_write.sh        # エージェントinboxへのメッセージ書き込み
│   ├── inbox_watcher.sh      # inotifywaitでinbox変更を監視
│   ├── switch_cli.sh         # ライブCLI/モデル切替（/exit → 再起動）
│   ├── ntfy.sh               # スマホにプッシュ通知を送信
│   └── ntfy_listener.sh      # スマホからのメッセージをストリーミング受信
│
├── config/
│   ├── settings.yaml         # 言語、ntfy、その他の設定
│   ├── ntfy_auth.env.sample  # ntfy認証テンプレート（セルフホスト用）
│   └── projects.yaml         # プロジェクト一覧
│
├── projects/                 # プロジェクト詳細（git対象外、機密情報含む）
│   └── <project_id>.yaml    # 各プロジェクトの全情報（クライアント、タスク、Notion連携等）
│
├── queue/                    # 通信ファイル
│   ├── shogun_to_karo.yaml   # 将軍から家老へのコマンド
│   ├── ntfy_inbox.yaml       # スマホからの受信メッセージ（ntfy）
│   ├── inbox/                # エージェント別inboxファイル
│   │   ├── shogun.yaml       # 将軍へのメッセージ
│   │   ├── karo.yaml         # 家老へのメッセージ
│   │   └── ashigaru{1-8}.yaml # 各足軽へのメッセージ
│   ├── tasks/                # 各ワーカーのタスクファイル
│   └── reports/              # ワーカーレポート
│
├── saytask/                  # 行動心理学に基づくモチベーション管理
│   └── streaks.yaml          # ストリーク追跡と日次進捗
│
├── templates/                # レポート・コンテキストテンプレート
│   ├── integ_base.md         # 統合: ベーステンプレート
│   ├── integ_fact.md         # 統合: ファクトファインディング
│   ├── integ_proposal.md     # 統合: 提案書
│   ├── integ_code.md         # 統合: コードレビュー
│   ├── integ_analysis.md     # 統合: 分析
│   └── context_template.md   # 汎用7セクション プロジェクトコンテキスト
│
├── skills/                   # 再利用可能スキル（リポジトリにコミット済み）
│   ├── skill-creator/        # スキル作成テンプレート
│   ├── shogun-agent-status/  # エージェント稼働状態表示
│   ├── shogun-model-list/    # モデル能力参照テーブル
│   ├── shogun-bloom-config/  # Bloom階層設定ツール
│   ├── shogun-model-switch/  # ライブCLI/モデル切替
│   └── shogun-readme-sync/   # README同期
│
├── memory/                   # Memory MCP保存場所
├── dashboard.md              # リアルタイム状況一覧
└── CLAUDE.md                 # システム指示書（自動読み込み）
```

</details>

---

## 📂 プロジェクト管理

このシステムは自身の開発だけでなく、**全てのホワイトカラー業務**を管理・実行する。プロジェクトのフォルダはこのリポジトリの外にあってもよい。

### 仕組み

```
config/projects.yaml          # プロジェクト一覧（ID・名前・パス・ステータスのみ）
projects/<project_id>.yaml    # 各プロジェクトの詳細情報
```

- **`config/projects.yaml`**: どのプロジェクトがあるかの一覧（サマリのみ）
- **`projects/<id>.yaml`**: そのプロジェクトの全詳細（クライアント情報、契約、タスク、関連ファイル、Notionページ等）
- **プロジェクトの実ファイル**（ソースコード、設計書等）は `path` で指定した外部フォルダに配置
- **`projects/` はGit追跡対象外**（クライアントの機密情報を含むため）

### 例

```yaml
# config/projects.yaml
projects:
  - id: my_client
    name: "クライアントXコンサルティング"
    path: "/mnt/c/Consulting/client_x"
    status: active

# projects/my_client.yaml
id: my_client
client:
  name: "クライアントX"
  company: "X株式会社"
contract:
  fee: "月額"
current_tasks:
  - id: task_001
    name: "システムアーキテクチャレビュー"
    status: in_progress
```

この分離設計により、将軍システムは複数の外部プロジェクトを横断的に統率しつつ、プロジェクトの詳細情報はバージョン管理の対象外に保つことができる。

---

## 🔧 トラブルシューティング

<details>
<summary><b>npm版のClaude Code CLIを使っている？</b></summary>

npm版（`npm install -g @anthropic-ai/claude-code`）は公式で非推奨（deprecated）になりました。`first_setup.sh` を再実行すると、npm版を検出してネイティブ版への移行を提案します。

```bash
# first_setup.sh を再実行
./first_setup.sh

# npm版が検出されると以下のメッセージが表示される:
# ⚠️ npm版 Claude Code CLI が検出されました（公式非推奨）
# ネイティブ版をインストールしますか? [Y/n]:

# Y を選択後、npm版をアンインストール:
npm uninstall -g @anthropic-ai/claude-code
```

</details>

<details>
<summary><b>MCPツールが動作しない？</b></summary>

MCPツールは「遅延ロード」方式で、最初にロードが必要です：

```
# 間違い - ツールがロードされていない
mcp__memory__read_graph()  ← エラー！

# 正しい - 先にロード
ToolSearch("select:mcp__memory__read_graph")
mcp__memory__read_graph()  ← 動作！
```

</details>

<details>
<summary><b>エージェントが権限を求めてくる？</b></summary>

`--dangerously-skip-permissions` 付きで起動していることを確認：

```bash
claude --dangerously-skip-permissions --system-prompt "..."
```

</details>

<details>
<summary><b>ワーカーが停止している？</b></summary>

ワーカーのペインを確認：
```bash
tmux attach-session -t multiagent
# Ctrl+B の後に数字でペインを切り替え
```

</details>

<details>
<summary><b>将軍やエージェントが落ちた？（Claude Codeプロセスがkillされた）</b></summary>

**`css` 等のtmuxセッション起動エイリアスを使って再起動してはいけません。** これらのエイリアスはtmuxセッションを作成するため、既存のtmuxペイン内で実行するとセッションがネスト（入れ子）になり、入力が壊れてペインが使用不能になります。

**正しい再起動方法：**

```bash
# 方法1: ペイン内でclaudeを直接実行
claude --model opus --dangerously-skip-permissions

# 方法2: 家老がrespawn-paneで強制再起動（ネストも解消される）
tmux respawn-pane -t shogun:0.0 -k 'claude --model opus --dangerously-skip-permissions'
```

**誤ってtmuxをネストしてしまった場合：**
1. `Ctrl+B` の後 `d` でデタッチ（内側のセッションから離脱）
2. その後 `claude` を直接実行（`css` は使わない）
3. デタッチが効かない場合は、別のペインから `tmux respawn-pane -k` で強制リセット

</details>

---

## 📚 tmux クイックリファレンス

| コマンド | 説明 |
|----------|------|
| `tmux attach -t shogun` | 将軍に接続 |
| `tmux attach -t multiagent` | ワーカーに接続 |
| `Ctrl+B` の後 `0-8` | ペイン間を切り替え |
| `Ctrl+B` の後 `d` | デタッチ（実行継続） |
| `tmux kill-session -t shogun` | 将軍セッションを停止 |
| `tmux kill-session -t multiagent` | ワーカーセッションを停止 |

### 🖱️ マウス操作

`first_setup.sh` が `~/.tmux.conf` に `set -g mouse on` を自動設定するため、マウスによる直感的な操作が可能です：

| 操作 | 説明 |
|------|------|
| マウスホイール | ペイン内のスクロール（出力履歴の確認） |
| ペインをクリック | ペイン間のフォーカス切替 |
| ペイン境界をドラッグ | ペインのリサイズ |

キーボード操作に不慣れな場合でも、マウスだけでペインの切替・スクロール・リサイズが行えます。

---

## v3.5の新機能 — Dynamic Model Routing

> **タスクに最適なモデルへ — エージェント再起動なしで。** Sonnet 4.6がOpusとの差を1.2pp（SWE-bench 79.6% vs 80.8%）まで縮め、タスク単位のモデルルーティングがはじめて費用対効果の合う選択に。

- **Bloom Dynamic Model Routing** — `capability_tiers` でモデルごとにBloom上限を定義。L1-L3→Spark（1000+ tok/s）、L4→Sonnet 4.6、L5→Sonnet 4.6 + extended thinking、L6→Opus（本当に新規な設計のみ）。エージェント再起動不要で切り替わる
- **Sonnet 4.6が新標準** — SWE-bench 79.6%、Opus 4.6との差わずか1.2pp。軍師をOpus→Sonnet 4.6に降格。全足軽のデフォルトもSonnet 4.6に。YAML1行を変えるだけ、再起動不要
- **`/shogun-model-list` スキル** — 全CLIツール × モデル × サブスクリプション × Bloom上限の参照テーブル。Sonnet 4.6とSparkの位置づけを更新
- **`/shogun-bloom-config` スキル** — 対話式設定: 2つの質問に答えるだけで最適な `capability_tiers` YAMLを生成

<details>
<summary><b>v3.4の機能 — Bloom→エージェントルーティング、E2Eテスト、Stop Hook</b></summary>

- **Bloom→エージェントルーティング** — 動的モデル切り替えをエージェントレベルのルーティングに置換。L1-L3→足軽、L4-L6→軍師。セッション中の `/model opus` 昇格は不要に
- **軍師（Gunshi）がファーストクラスエージェントに** — ペイン8の戦略参謀。深い分析、設計レビュー、アーキテクチャ評価を担当
- **E2Eテストスイート（19テスト、7シナリオ）** — モックCLIフレームワークが分離されたtmuxセッションでエージェント動作をシミュレート
- **Stop hook inbox配信** — Claude Codeエージェントが `.claude/settings.json` のStop hookでターン終了時に自動的にinboxを確認。`send-keys` 割り込み問題を根絶
- **モデルデフォルト更新** — 家老: Opus→Sonnet。軍師: Opus（深い推論）。全足軽: Sonnet（統一）
- **Codex CLIスタートアッププロンプト** — `cli_adapter.sh` の `get_startup_prompt()` が初期 `[PROMPT]` 引数をCodex CLIに渡す
- **YAMLスリム化ユーティリティ** — `scripts/slim_yaml.sh` が既読メッセージ・完了コマンドをアーカイブ

</details>

## v3.3.2の新機能 — GPT-5.3-Codex-Spark対応

> **新モデル、同じYAML。** `settings.yaml` の任意のCodexエージェントに `model: gpt-5.3-codex-spark` を追加するだけ。

- **Codex `--model` フラグ対応** — `build_cli_command()` が `settings.yaml` のモデル設定を `--model` フラグ経由でCodex CLIに渡す。`gpt-5.3-codex-spark` と今後のCodexモデルに対応
- **独立レート制限** — SparkはGPT-5.3-Codexとは独立したレート制限枠で動作。異なる足軽に両モデルを割り当てれば**実効スループットが2倍**に
- **起動時表示** — `shutsujin_departure.sh` が汎用的なエフォートレベルの代わりに実際のモデル名（例: `codex/gpt-5.3-codex-spark`）を表示

<details>
<summary><b>v3.0の機能 — Multi-CLI</b></summary>

- **Multi-CLIがファーストクラスアーキテクチャに** — `lib/cli_adapter.sh` がエージェントごとにCLIを動的選択
- **OpenAI Codex CLI統合** — GPT-5.3-codexを `--dangerously-bypass-approvals-and-sandbox` で真の自律実行
- **ハイブリッドアーキテクチャ** — 指揮層はClaude Code固定、作業層はCLI非依存
- **コミュニティ貢献** — [@yuto-ts](https://github.com/yuto-ts)、[@circlemouth](https://github.com/circlemouth)、[@koba6316](https://github.com/koba6316)

</details>

<details>
<summary><b>v2.0の機能</b></summary>

- **ntfy双方向通信** — スマホからコマンドを送信、タスク完了時にプッシュ通知を受信
- **SayTask通知** — ストリーク追跡、Eat the Frog、行動心理学に基づくモチベーション管理
- **ペインボーダータスク表示** — tmuxペインボーダーで各エージェントの現在のタスクを一目で確認
- **シャウトモード**（デフォルト）— 足軽がタスク完了時にパーソナライズされた戦国風の叫びを表示。`--silent` で無効化
- **エージェント自己監視+エスカレーション（v3.2）** — 各エージェントが自分のinboxファイルを `inotifywait` で監視（ポーリングゼロ、即座に起床）。フォールバック: `tmux send-keys` で短いnudge（テキストとEnterを分離送信、Codex CLI対応）。3段階エスカレーション: 標準nudge（0-2分）→ Escape×2+nudge（2-4分）→ `/clear` 強制リセット（4分以上）。Linux FSシンボリックリンクでWSL2の9P FS inotify問題を解決
- **エージェント自己識別**（`@agent_id`）— tmuxユーザーオプションによる安定したID、ペイン再配置の影響を受けない
- **決戦モード**（`-k` フラグ）— 全足軽Opusの最大能力陣形
- **タスク依存関係システム**（`blockedBy`）— 依存タスクの自動ブロック解除

</details>

---

## コントリビューション

Issue、Pull Requestを歓迎します。

- **バグ報告**: 再現手順を添えてIssueを作成してください
- **機能アイデア**: まずDiscussionで提案してください
- **スキル**: スキルは個人のワークフローに最適化されるものであり、このリポジトリには含めません

## 🙏 クレジット

[Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa をベースに開発。

---

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。

---

<div align="center">

**コマンド1つ。エージェント8体。連携コストゼロ。**

⭐ 役に立ったらスターをお願いします — 他の人にも見つけてもらえます。

</div>
