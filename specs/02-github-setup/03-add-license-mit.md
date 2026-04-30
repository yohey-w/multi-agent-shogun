---
phase: 2
task_id: 03-add-license-mit
agent: planner (Haiku 可)
estimated_minutes: 2
depends_on: [02-rename-local-dir]
---

# Task: LICENSE (MIT) を追加

## Goal
リポ root に MIT ライセンスファイルを配置。

## Steps
1. リポ root に `LICENSE` ファイルを作成、以下の内容:
```
MIT License

Copyright (c) 2026 Makoto Mizuno

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

2. commit:
```bash
git add LICENSE
git commit -m "chore: add MIT LICENSE"
```

## Verification
```bash
test -f LICENSE && head -1 LICENSE
# Expected: "MIT License"
```

## Notes
- Copyright holder は殿のフルネーム ("Makoto Mizuno")。pseudonym 希望の場合 spec 修正
- GitHub 側でも LICENSE が認識され、リポトップに「MIT」バッジが表示される
