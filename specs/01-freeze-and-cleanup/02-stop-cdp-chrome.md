---
phase: 1
task_id: 02-stop-cdp-chrome
agent: manual (殿)
estimated_minutes: 1
depends_on: []
---

# Task: CDP モード Chrome を終了

## Goal
v1.1 軍師 Phase C 用に立ち上げた CDP モード Chrome (`~/.cdp-chrome-profile`) を停止する。

## Inputs
- Chrome process: `--remote-debugging-port=9222 --user-data-dir=~/.cdp-chrome-profile` で起動したもの

## Steps
1. CDP Chrome ウィンドウで Cmd+Q (殿が手動)、または以下を殿のターミナルで実行:
```bash
osascript -e 'tell application "Google Chrome" to quit'
```

## Expected Output
- port 9222 が LISTEN しない
- `~/.cdp-chrome-profile` プロファイルの Chrome process 終了

## Verification
```bash
lsof -nP -iTCP:9222 -sTCP:LISTEN 2>/dev/null
# Expected: 何も出ない
curl -s --max-time 1 http://localhost:9222/json/version
# Expected: connection refused
```

## Notes
- `~/.cdp-chrome-profile` ディレクトリは残してよい (将来 v2 で再利用可能性)
- 殿の通常 Chrome (個人プロファイル) は別 process、Cmd+Q では消えない (別ウィンドウなら)
