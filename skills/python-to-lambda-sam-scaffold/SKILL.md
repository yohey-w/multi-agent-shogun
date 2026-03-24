---
name: python-to-lambda-sam-scaffold
description: |
  Make sure to use this skill whenever the user asks to migrate a Python script to AWS Lambda, create a SAM scaffold, or convert a cron/launchd job to serverless (「Lambda化」「SAM scaffold」「PythonスクリプトをLambdaに」「サーバーレスに移行」「EventBridgeスケジュール」).

  既存PythonスクリプトをLambda+SAMに移行する雛形一式を自動生成。セキュリティ対策(mask_secrets, validate_url, timeout)をデフォルト組込み。

  Key capabilities: (1) template.yaml生成(Lambda+EventBridge+IAM) (2) samconfig.toml生成(NoEchoパラメータ) (3) lambda_function.py生成(handler+セキュリティ関数) (4) requirements.txt自動抽出 (5) デプロイ手順README.md生成
version: 1.0.0
---

# Python to Lambda SAM Scaffold

既存のPythonスクリプト（CLIツール、定期実行スクリプト等）をAWS Lambda + SAMテンプレートに移行するための雛形一式を自動生成するスキル。#21 lambda-security-hardening-checklist のセキュリティ対策をデフォルト組込み済み。

## Overview

このスキルは、移行対象のPythonスクリプトを解析し、以下の成果物を一括生成する:

- `template.yaml` — SAMテンプレート（Lambda関数定義 + EventBridge Schedule + IAMロール + Parameters）
- `samconfig.toml` — デプロイ設定雛形（`parameter_overrides` にenv_varsをプレースホルダで配置）
- `lambda_function.py` — 元スクリプトに `lambda_handler` エントリポイントを追加した版（セキュリティ関数付き）
- `requirements.txt` — 元スクリプトのimportを解析し、必要パッケージを列挙
- `README.md` — デプロイ手順書（前提条件、初回/更新デプロイ、テスト手順）
- `.gitignore` への追記 — `samconfig.toml`, `.aws-sam/`

## When This Skill Applies

- ユーザーが「Lambda化」「SAM scaffold」「PythonスクリプトをLambdaに」「サーバーレスに移行」等を求めた時
- ローカルで動作しているPython定期実行スクリプト（launchd/cron）をLambdaに移設する時
- 新規PythonツールをLambdaとして構築する時の初期セットアップ
- 既存Lambda関数のSAM管理化（手動作成リソースのIaC移行）

## 入力パラメータ

ユーザーから以下のパラメータを収集する:

| パラメータ | 必須 | デフォルト | 説明 |
|-----------|------|-----------|------|
| `source_script` | Yes | - | 移行対象Pythonスクリプトのパス |
| `function_name` | Yes | - | Lambda関数名（例: `s-fit-daily-progress-report`） |
| `schedule` | No | なし | EventBridge Schedule式（例: `cron(0 21 ? * SUN-THU *)`） |
| `env_vars` | Yes | - | 環境変数の名前リスト（値は含まない。例: `JIRA_EMAIL,JIRA_API_TOKEN,NOTION_TOKEN`） |
| `runtime` | No | `python3.13` | Lambdaランタイム |
| `timeout` | No | `120` | Lambda実行タイムアウト秒 |
| `memory` | No | `256` | Lambdaメモリサイズ(MB) |

## 処理フロー

### Step 1: requirements.txt 生成

1. Read toolで `source_script` の内容を読み取る
2. Grep toolでimport文を抽出する
3. 標準ライブラリとサードパーティパッケージを分類する:
   - 標準ライブラリ判定: `os`, `sys`, `json`, `logging`, `re`, `time`, `datetime`, `typing`, `urllib`, `pathlib`, `collections`, `itertools`, `functools`, `hashlib`, `base64`, `io`, `csv`, `math`, `copy`, `abc`, `enum`, `dataclasses`, `contextlib`, `traceback`, `inspect`, `textwrap`, `string`, `secrets`, `uuid`, `tempfile`, `shutil`, `glob`, `subprocess` 等
   - 上記以外のimportをサードパーティとして `requirements.txt` に記載
4. Write toolで `requirements.txt` を生成

```
# Auto-generated from {source_script}
# Review and pin versions before deploying to production
requests
notion-client
```

### Step 2: template.yaml 生成

以下の構造でSAMテンプレートを生成する:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: {function_nameから推測した説明}

Parameters:
  # env_varsの各変数をNoEchoパラメータとして展開
  {EnvVarName}:
    Type: String
    NoEcho: true
    Description: {EnvVarName}

Resources:
  {FunctionNamePascalCase}Function:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: {function_name}
      Handler: lambda_function.lambda_handler
      Runtime: {runtime}
      MemorySize: {memory}
      Timeout: {timeout}
      Environment:
        Variables:
          # env_varsの各変数を!Refで参照
          {ENV_VAR_NAME}: !Ref {EnvVarName}
      # scheduleが指定されている場合のみ
      Events:
        ScheduleEvent:
          Type: Schedule
          Properties:
            Schedule: {schedule}
            Description: "{function_name} scheduled execution"

Outputs:
  {FunctionNamePascalCase}FunctionArn:
    Description: Lambda Function ARN
    Value: !GetAtt {FunctionNamePascalCase}Function.Arn
```

**注意点:**
- `env_vars` の各変数名をPascalCaseに変換してParametersのキーにする（例: `JIRA_API_TOKEN` → `JiraApiToken`）
- Environment.Variables では元の大文字スネークケース名を使い、`!Ref` でParametersを参照する
- `schedule` が未指定の場合、Eventsセクション全体を省略する

### Step 3: samconfig.toml 生成

```toml
version = 0.1

[default.deploy.parameters]
stack_name = "{function_name}"
resolve_s3 = true
s3_prefix = "{function_name}"
region = "ap-northeast-1"
capabilities = "CAPABILITY_IAM"
confirm_changeset = true
parameter_overrides = "{env_var1}=\"CHANGE_ME\" {env_var2}=\"CHANGE_ME\""
```

- `parameter_overrides` には `env_vars` の各変数名（PascalCase）を `"CHANGE_ME"` プレースホルダで配置
- ユーザーがデプロイ前に実際の値に書き換える想定

### Step 4: lambda_function.py 生成

元スクリプトを変換して `lambda_function.py` を生成する:

1. 元スクリプトの `if __name__ == '__main__'` ブロック（または `main()` 関数呼び出し）を検出
2. `lambda_handler(event, context)` でメイン処理をラップ
3. 以下のセキュリティ関数をファイル先頭（import文の後）に挿入:

```python
def mask_secrets(text: str) -> str:
    """ログ出力前にシークレット候補文字列をマスクする"""
    secrets = []
    for key in ['{ENV_VAR_1}', '{ENV_VAR_2}', ...]:  # env_varsから展開
        val = os.environ.get(key, '')
        if val and len(val) > 3:
            secrets.append(val)
    for secret in secrets:
        text = text.replace(secret, '***')
    return text


def validate_url(url: str, allowed_domains: list) -> None:
    """URLが許可ドメインリストに含まれているか検証する（SSRF対策）"""
    from urllib.parse import urlparse
    parsed = urlparse(url)
    if parsed.scheme != 'https':
        raise ValueError(f"URL must use HTTPS: {url}")
    if not any(parsed.netloc.endswith(domain) for domain in allowed_domains):
        raise ValueError(f"URL domain not in allowlist: {parsed.netloc}")
```

4. 全 `requests.get` / `requests.post` 呼び出しに `timeout=(10, 30)` が付与されているか確認:
   - 付与済み → そのまま
   - 未付与 → 警告メッセージを出力し、ユーザーに手動追加を促す

5. `lambda_handler` の構造:

```python
def lambda_handler(event, context):
    """AWS Lambda エントリーポイント"""
    main()
    return {
        'statusCode': 200,
        'body': '{function_name} completed successfully'
    }


if __name__ == '__main__':
    main()
```

### Step 5: .gitignore 追記

`.gitignore` ファイルを確認し、以下のエントリがなければ追記する:

```
# AWS SAM
samconfig.toml
.aws-sam/
```

### Step 6: README.md 生成

以下の構造でREADMEを生成する:

```markdown
# {function_name}

{source_scriptの機能に基づく1行説明}

## 前提条件

- AWS CLI（設定済み）
- AWS SAM CLI
- Python {runtime のバージョン部分}

## 必要な環境変数

Lambda関数の環境変数として以下を設定してください:

| 変数名 | 説明 |
|--------|------|
| {ENV_VAR_1} | {変数の説明} |
| ...

**注意**: 認証情報の値はこのREADMEには記載しません。`samconfig.toml` の `parameter_overrides` に設定してください。

## ローカル手動実行

```bash
export {ENV_VAR_1}="your-value"
...
python lambda_function.py
```

## デプロイ

### 初回デプロイ

```bash
sam build
sam deploy --guided
```

`--guided` で対話的にパラメータを設定します。設定は `samconfig.toml` に保存されます。

### 2回目以降のデプロイ

```bash
sam build
sam deploy
```

## Lambda手動実行

```bash
aws lambda invoke \
  --function-name {function_name} \
  --profile {適切なプロファイル名} \
  /dev/stdout
```
```

**scheduleが指定されている場合、以下のセクションも追加:**

```markdown
## EventBridgeスケジュール

- **スケジュール式**: `{schedule}`
- **説明**: {実行タイミングの日本語説明}
```

## セキュリティ対策（デフォルト組込み）

#21 lambda-security-hardening-checklist から統合した以下の対策が、生成コードにデフォルトで組み込まれる:

| 対策 | 内容 | 実装箇所 |
|------|------|----------|
| timeout追加 | 全HTTP呼び出しに `timeout=(10, 30)` | lambda_function.py 内の requests 呼び出し |
| validate_url | SSRF対策のURL検証関数 | lambda_function.py 先頭に定義 |
| mask_secrets | ログ出力時のシークレットマスク関数 | lambda_function.py 先頭に定義 |
| 未使用import検出 | 不要なimportの警告 | Step 1のimport解析時 |

## 実装指示

Claude Codeがこのスキルを実行する際の手順:

1. **パラメータ収集**: ユーザーから `source_script`, `function_name`, `env_vars` を確認。`schedule`, `runtime`, `timeout`, `memory` はオプション（デフォルト値あり）
2. **ソース解析**: Read toolで `source_script` を読み、Grep toolでimport文を抽出。標準ライブラリ vs サードパーティを分類
3. **ファイル生成**: Write toolで以下を順次生成:
   - `requirements.txt`（Step 1）
   - `template.yaml`（Step 2）
   - `samconfig.toml`（Step 3）
   - `lambda_function.py`（Step 4）
   - `.gitignore` 追記（Step 5）
   - `README.md`（Step 6）
4. **検証**: 生成した `template.yaml` が有効なSAMテンプレートであること、`lambda_function.py` に `lambda_handler` が定義されていること、`requirements.txt` に必要パッケージが含まれていることを確認
5. **セキュリティチェック**: `lambda_function.py` 内の全 `requests.get`/`requests.post` に `timeout` が付与されているか確認。未付与があればユーザーに警告

## Best Practices

- `samconfig.toml` には認証情報のプレースホルダが含まれるため、必ず `.gitignore` に追加する
- 参考成果物に含まれる認証情報やAPIキーは絶対に転記・引用しない
- `parameter_overrides` の値は `"CHANGE_ME"` のまま生成し、ユーザーがデプロイ前に書き換える
- Lambdaのタイムアウトはデフォルト120秒だが、処理内容に応じてユーザーが調整する
- EventBridge Scheduleは UTC 表記。日本時間との差（+9時間）を README に明記する
