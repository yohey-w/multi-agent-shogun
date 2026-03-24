---
name: laravel-enum-seeder-validator
description: |
  Make sure to use this skill whenever the user asks to validate enum values in Laravel seeders, check enum consistency, or detect enum mismatches before seeder execution (「enum検証」「enum整合性チェック」「seederバリデーション」「enum不整合確認」「Seeder投入前のenum確認」).

  LaravelのSeederが参照するenum値とEnumクラスのcase定義を静的照合し、不整合を検出。実行時エラーを開発段階で早期発見する。

  Key capabilities: (1) Enum全case定義スキャンでFQCN付きマッピング構築 (2) Seeder内3パターン検出（直接参照・値取得・文字列リテラル） (3) NG/WARN分類+行番号付きMarkdownレポート (4) --strictで未使用case警告 (5) Glob/Readツールのみ使用
version: 1.0.0
---

# Laravel Enum Seeder Validator

Seederファイル内で使用しているenum値がLaravel Enumクラスのcase定義と整合しているかを静的検証し、実行時エラー（DbInconsistencyException、LogicException等）を開発段階で防止するスキル。

## Overview

このスキルは、Enumクラス定義ディレクトリとSeederディレクトリを入力として、以下を実行する:

1. Enumクラスの全case定義をスキャンしてマッピングを構築
2. Seederファイル内のenum参照を検出
3. 参照とマッピングを照合し、不整合を検出
4. 結果を構造化レポートとして出力

## When This Skill Applies

このスキルは以下の場合に適用される:
- ユーザーが「enum検証」「seederバリデーション」「enum整合性チェック」を求めた時
- Seeder作成・修正後の品質チェックを求めた時
- Enum定義変更後の影響範囲確認を求めた時
- UAT用テストデータSeeder投入前の事前検証

## 入力パラメータ

| パラメータ | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| `enum_dir` | Yes | Enumクラスが配置されたディレクトリパス | `app/Enums/` |
| `seeder_dir` | Yes | Seederファイルが配置されたディレクトリパス | `database/seeders/` |
| `--strict` | No | 未使用enum値（Seederで未参照のcase）も警告する | - |

## 処理フロー

### Step 1: Enumクラス定義のスキャン

`enum_dir`配下の全PHPファイルをGlobで検索し、Readで読み込む。

**検出パターン:**
- enum宣言: `enum\s+(\w+)\s*:\s*(string|int)`
- case定義: `case\s+(\w+)\s*=\s*['"]?([^'";]+)['"]?`

**構築するマッピング:**

```
EnumClassName:
  type: string|int
  fqcn: App\Enums\Xxx\EnumClassName
  cases:
    CaseName1: 'value1'
    CaseName2: 'value2'
```

手順:
1. `Glob` で `{enum_dir}/**/*.php` を検索
2. 各ファイルを `Read` で読み込み
3. `namespace` 行からFQCNを構築
4. `enum XxxType: string` パターンでenum宣言を検出
5. `case CaseName = 'value'` パターンで全caseを抽出
6. クラス名→{FQCN, type, cases}のマッピングを構築

### Step 2: Seederファイル内のenum参照検出

`seeder_dir`配下の全PHPファイルをスキャンし、enum参照を検出する。

**検出パターン（3種類）:**

1. **直接参照**: `(\w+Type|\w+Status|\w+Category)::(\w+)`
   - 例: `BranchType::HeadOffice`, `Post::Manager`
2. **値取得**: `(\w+Type|\w+Status|\w+Category)::(\w+)->value`
   - 例: `RoleType::Admin->value`
3. **文字列リテラル（ヒューリスティック）**: enumのcase値と完全一致する文字列リテラル
   - 例: `'head_office'` がBranchType::HeadOfficeの値と一致

手順:
1. `Glob` で `{seeder_dir}/**/*.php` を検索
2. 各ファイルを `Read` で読み込み
3. `use` 文からenum importを検出し、短縮名→FQCNマッピングを構築
4. 上記3パターンの正規表現で全enum参照を行番号付きで抽出

### Step 3: 照合と不整合検出

Step 1のマッピングとStep 2の参照を照合する。

**検出する不整合:**

| 種類 | 条件 | 重要度 |
|------|------|--------|
| 存在しないcase参照 | `XxxType::UnknownCase` がマッピングに存在しない | NG |
| 値の不一致 | 文字列リテラルがどのcaseの値とも一致しない | NG |
| 未import enum | 参照はあるがuse文にenumクラスがない | WARN |
| 未使用case（--strict時のみ） | マッピングに存在するがSeederで未参照のcase | WARN |

### Step 4: 結果出力

#### OK出力（不整合なし）

```markdown
## Enum Seeder Validation Result: ALL PASSED

| Seeder File | Enum References | Status |
|-------------|-----------------|--------|
| UatEmployeeSeeder.php | BranchType(3), Post(5), RoleType(2) | OK |
| UatWorkflowSeeder.php | WorkflowStatus(4) | OK |

Total: 2 files, 14 references, 0 issues
```

#### NG出力（不整合あり）

```markdown
## Enum Seeder Validation Result: FAILED

### NG: Mismatched Enum References

| File | Line | Reference | Issue | Expected |
|------|------|-----------|-------|----------|
| UatBillingSeeder.php | 45 | TransactionCategory::CommissionSale | Case not found | Available: Sales, Purchase, Transfer, Refund |
| UatComplaintSeeder.php | 78 | ComplaintStatus::resolved | Case not found (case-sensitive) | Available: Resolved, Pending, Closed |

### OK: Valid Enum References

| Seeder File | Enum References | Status |
|-------------|-----------------|--------|
| UatEmployeeSeeder.php | BranchType(3), Post(5) | OK |

Total: 3 files, 12 references, 2 issues
Exit code: 1
```

#### WARN出力（--strict時、未使用case）

```markdown
### WARN: Unused Enum Cases (--strict)

| Enum Class | Unused Cases | Total Cases | Used |
|------------|-------------|-------------|------|
| BranchType | Warehouse, Laboratory | 9 | 7 |
| Post | Intern | 49 | 48 |
```

## 実装指示

Claude Codeに対する指示:

1. **ファイル検索にはGlobツールを使用する**（bashのfindは使わない）
2. **ファイル読み込みにはReadツールを使用する**（bashのcat/grepは使わない）
3. **パターン検索にはGrepツールを使用する**（bashのgrepは使わない）
4. 正規表現ベースの解析を行う（PHPのAST解析は不要）
5. 結果はMarkdownテーブル形式で出力する
6. 不整合検出時はexit code概念として1（NG検出あり）をユーザーに伝える

### 主要正規表現

| 対象 | パターン |
|------|----------|
| enum宣言 | `enum\s+(\w+)\s*:\s*(string\|int)` |
| case定義 | `case\s+(\w+)\s*=\s*['"]?([^'";]+)['"]?` |
| enum参照（直接） | `(\w+Type\|\w+Status\|\w+Category)::(\w+)` |
| use文 | `use\s+([\w\\\\]+\\\\(\w+));` |
| namespace | `namespace\s+([\w\\\\]+);` |

## Best Practices

- enum_dirは再帰的にスキャンする（サブディレクトリ内のenumも対象）
- Seeder内のコメント行（`//`, `/* */`）は検出対象から除外する
- enum参照パターンはType/Status/Category以外のサフィックスも拡張可能だが、デフォルトはこの3種
- 大量のenum定義がある場合、Step 1の結果を一覧表示してユーザーに確認を求めてもよい
- 文字列リテラルのヒューリスティック検出は偽陽性が出やすいため、確信度が低い場合はWARNとして出力する
