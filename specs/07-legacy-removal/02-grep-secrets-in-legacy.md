---
phase: 7
task_id: 02-grep-secrets-in-legacy
agent: planner (Haiku 可、grep 結果を人間 (殿) が見て判断)
estimated_minutes: 10
depends_on: [01-move-old-files-to-legacy]
---

# Task: legacy/ 内の機密情報スキャン

## Goal
削除前に「あれ?機密情報含まれてた?」のリスクを潰す。gitleaks + 殿手動 grep。

## Steps
1. gitleaks で legacy をスキャン:
```bash
gitleaks detect --source legacy --config .gitleaks.toml --verbose --no-git --report-format json --report-path /tmp/legacy-leaks.json
echo "---summary---"
jq '. | length' /tmp/legacy-leaks.json 2>/dev/null
```

2. 主な漏洩候補の手動 grep:
```bash
echo "=== potential secrets ==="
grep -rE 'sk-[a-zA-Z0-9-_]{30,}|sk-ant-[a-zA-Z0-9-_]{30,}|AKIA[A-Z0-9]{16}|ghp_[A-Za-z0-9]{36}|password\s*=|secret\s*=|token\s*=|api_key' legacy/ 2>/dev/null | head -30
echo ""
echo "=== personal info ==="
grep -rEi 'mail.*@|ssn|credit.*card|phone.*[0-9]{3}-[0-9]{3,}' legacy/ 2>/dev/null | head -20
```

3. 殿に出力を見せて判断:
   - 検出ゼロ → 次 task で削除 OK
   - 検出あり → 該当ファイルを精査、git history 含めて完全削除 (BFG Repo-Cleaner 等) を planner が指示

4. もし legacy 内 commit log 自体に secret 含まれている場合 (例: 過去 commit に API key 直書き):
```bash
# git filter-repo で履歴ごと削除する task を別途立てる
echo "WARNING: secret in git history detected, see /tmp/legacy-leaks.json"
exit 1
```

5. 検出ゼロなら結果を `legacy/_SCAN_REPORT.md` に保存:
```bash
echo "# Legacy Scan Report ($(date +%Y-%m-%d))" > legacy/_SCAN_REPORT.md
echo "" >> legacy/_SCAN_REPORT.md
echo "## gitleaks" >> legacy/_SCAN_REPORT.md
echo "leaks count: $(jq '. | length' /tmp/legacy-leaks.json 2>/dev/null || echo 0)" >> legacy/_SCAN_REPORT.md
echo "" >> legacy/_SCAN_REPORT.md
echo "## manual grep (secrets)" >> legacy/_SCAN_REPORT.md
echo '```' >> legacy/_SCAN_REPORT.md
grep -rE 'sk-[a-zA-Z0-9-_]{30,}|AKIA[A-Z0-9]{16}|ghp_[A-Za-z0-9]{36}' legacy/ 2>/dev/null | head -10 >> legacy/_SCAN_REPORT.md
echo '```' >> legacy/_SCAN_REPORT.md
echo "" >> legacy/_SCAN_REPORT.md
echo "## verdict" >> legacy/_SCAN_REPORT.md
echo "- if all empty: SAFE TO DELETE" >> legacy/_SCAN_REPORT.md
echo "- otherwise: see git filter-repo plan" >> legacy/_SCAN_REPORT.md
```

## Verification
- gitleaks 検出 0
- 手動 grep 0 件 or 確認済 false positive のみ

## Notes
- 過去 commit の secret は git history 改変が必要 (重大、別仕様で扱う)
- 大半のケースは「設定ファイル系を gitignore 済」「commit に secret 入ってない」で安全
- false positive 例: spec / docs 内の説明用 placeholder (gitleaks allowlist で除外済)
