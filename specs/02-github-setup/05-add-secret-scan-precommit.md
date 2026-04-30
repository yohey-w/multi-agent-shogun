---
phase: 2
task_id: 05-add-secret-scan-precommit
agent: planner (Haiku 可)
estimated_minutes: 5
depends_on: [04-add-gitignore]
---

# Task: pre-commit / pre-push hook で secret scan (gitleaks)

## Goal
push 前に機密情報 (API key, AWS credentials, private key 等) が紛れていないか自動検知する仕組みを入れる。

## Steps
1. gitleaks をインストール (殿のマシンに既にあるか確認):
```bash
which gitleaks || brew install gitleaks
```
インストール済なら version 確認のみ。

2. リポ root に `.gitleaks.toml` (設定ファイル) を作成:
```toml
title = "agent-orchestra gitleaks config"

[extend]
useDefault = true

[[allowlist]]
description = "Public extension keys (manifest.json) — RSA pub keys, not secrets"
paths = [
    '''.*manifest\.json$''',
]

[[allowlist]]
description = "Spec / docs example placeholders"
paths = [
    '''specs/.*\.md$''',
    '''docs/.*\.md$''',
]
```

3. リポ root に `.pre-commit-config.yaml` を作成:
```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
        name: gitleaks (secret scan)
```

4. ローカル hook 有効化:
```bash
pip3 install --user pre-commit 2>/dev/null || brew install pre-commit
pre-commit install --hook-type pre-commit
pre-commit install --hook-type pre-push
```

5. 動作確認 (履歴フルスキャン):
```bash
gitleaks detect --source . --config .gitleaks.toml --verbose --no-git
# Expected: "no leaks found" or 既知の false positive のみ
```

6. もし leak 検出された場合は legacy/ 移動 → 削除フェーズで対処、現時点では allowlist 追加 or 該当ファイル削除。

7. commit:
```bash
git add .gitleaks.toml .pre-commit-config.yaml
git commit -m "chore: add gitleaks secret scan via pre-commit (pre-commit + pre-push)"
```

## Verification
- pre-commit と pre-push hook が `.git/hooks/` に書かれている:
```bash
ls .git/hooks/pre-commit .git/hooks/pre-push
```
- 試しに ".env" にダミーキーを書いて add → commit すると blocked される (確認後すぐ rollback):
```bash
echo "AKIAIOSFODNN7EXAMPLE" > /tmp/test.env
cp /tmp/test.env .env
git add .env -f
git commit -m "test"
# Expected: gitleaks が AWS key 検出して exit 1
git reset HEAD .env && rm .env
```

## Notes
- macOS なら brew install gitleaks pre-commit が一番楽
- gitleaks デフォルトルールで主要 cloud / VCS / DB のキーは検出
- false positive 多発する場合は allowlist で個別除外
