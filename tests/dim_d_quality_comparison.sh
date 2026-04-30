#!/usr/bin/env bash
# dim_d_quality_comparison.sh — Dim D: 出力品質比較実験
# Usage: bash tests/dim_d_quality_comparison.sh
#
# 同一L5タスクを Bloom非対応モデル(Haiku 4.5) と 対応モデル(Sonnet 4.6) に実行させ、
# Gunshi(Opus 4.6)が品質を採点して差を証明する。
#
# 合格基準:
#   Sonnet 4.6 の score >= 70 (L5基準: 3案+根拠つき推奨)
#   Haiku 4.5  の score <= 50 (L5タスクを処理しきれない)
#   差分 >= 15 point

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${PROJECT_ROOT}/queue/reports/dim_d_quality_report.yaml"

echo "══ Dim D: 出力品質比較実験 ══"
echo "タスク種別: L5 (Evaluate) — 実装案比較・推奨"
echo "非対応モデル: claude-haiku-4-5-20251001 (max_bloom=3)"
echo "対応モデル:   claude-sonnet-4-6         (max_bloom=5)"
echo "評価者:       claude-opus-4-6           (max_bloom=6)"
echo ""

python3 << PYEOF
import subprocess, re, sys, os, json
from pathlib import Path
from datetime import datetime
import yaml

project_root = Path("${PROJECT_ROOT}")

# CLAUDECODE env var を外してネスト検出を回避
env = os.environ.copy()
env.pop('CLAUDECODE', None)

# claude CLIパス解決
import glob as _glob
claude_cmd = subprocess.run(['which', 'claude'], capture_output=True, text=True, env=env).stdout.strip()
if not claude_cmd:
    candidates = (
        _glob.glob(os.path.expanduser('~/.local/bin/claude')) +
        _glob.glob(os.path.expanduser('~/.nvm/versions/node/*/bin/claude')) +
        ['/usr/local/bin/claude']
    )
    claude_cmd = next((c for c in candidates if os.path.isfile(c)), 'claude')
print(f"claude CLI: {claude_cmd}")

# ─────────────────────────────────────────────
# L5タスク定義
# ─────────────────────────────────────────────
L5_TASK = """マルチエージェントシステムで「アイドル足軽への動的タスク割り当て」を実装したい。
以下の3案を比較し、最善案を根拠とともに推奨せよ。

【案A】ポーリング方式: 家老が1秒ごとに全足軽のステータスファイルを確認し、
       アイドルを検出したらタスクを送信する。

【案B】イベント駆動方式: 足軽がタスク完了時にinbox_writeで「完了通知」を送り、
       家老は通知を受けてから次のタスクを送信する。

【案C】優先キュー方式: タスクにBloomレベルを付与し、対応モデルを持つ
       アイドル足軽の中から最低コストの足軽を選んで割り当てる。

各案について: (1)実装コスト, (2)レスポンス速度, (3)拡張性, (4)障害耐性 を評価し、
最善案を選んでその理由を論じよ。"""

EVALUATOR_PROMPT_TEMPLATE = """以下の「マルチエージェントシステムのタスク割り当て実装案比較」への回答を採点せよ。

採点基準（L5 Evaluate レベル）:
1. 案の数 (0-20点): 3案全てに対してコメントがあるか
2. 評価軸の適用 (0-25点): 実装コスト/速度/拡張性/障害耐性の4軸で評価しているか
3. 推奨案の明示 (0-25点): 最善案を明確に推奨し、その理由を述べているか
4. 論拠の深さ (0-30点): 各案の比較が表面的でなく、技術的根拠が含まれているか

合計100点満点。JSONのみで返答せよ（説明不要）:
{"score": <整数>, "breakdown": {"案の数": <整数>, "評価軸": <整数>, "推奨明示": <整数>, "論拠深さ": <整数>}, "summary": "<一行評価>"}

--- 採点対象の回答 ---
"""

def run_model(model_id, prompt, timeout=120):
    """指定モデルでclaudeを直接呼び出す"""
    print(f"\n[{model_id}] 実行中...", flush=True)
    try:
        result = subprocess.run(
            [claude_cmd, '--model', model_id, '-p', prompt],
            capture_output=True, text=True, timeout=timeout,
            env=env
        )
        out = result.stdout.strip()
        if not out and result.stderr:
            print(f"  STDERR: {result.stderr[:200]}", flush=True)
        return out
    except subprocess.TimeoutExpired:
        print(f"  TIMEOUT ({timeout}s)")
        return None
    except Exception as e:
        print(f"  ERROR: {e}")
        return None

def evaluate(response, model_label, timeout=90):
    """Opus 4.6 で品質スコアを算出"""
    if not response:
        return {"score": 0, "error": "no response"}
    prompt = EVALUATOR_PROMPT_TEMPLATE + response[:3000]
    print(f"\n[Gunshi/Opus評価] {model_label}の回答を採点中...", flush=True)
    raw = run_model('claude-opus-4-6', prompt, timeout=timeout)
    if not raw:
        return {"score": 0, "error": "evaluator failed"}
    # JSON抽出
    match = re.search(r'\{.*\}', raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except:
            pass
    # fallback: スコア数値のみ抽出
    nums = re.findall(r'"score"\s*:\s*(\d+)', raw)
    return {"score": int(nums[0]) if nums else 0, "raw": raw[:500]}

# ─────────────────────────────────────────────
# 実行
# ─────────────────────────────────────────────
print("\n── Step 1/3: Haiku 4.5 (max_bloom=3, L5タスクに非対応) ──")
haiku_response = run_model('claude-haiku-4-5-20251001', L5_TASK)
if haiku_response:
    print(f"  出力 ({len(haiku_response)} chars): {haiku_response[:200]}...")

print("\n── Step 2/3: Sonnet 4.6 (max_bloom=5, L5タスクに対応) ──")
sonnet_response = run_model('claude-sonnet-4-6', L5_TASK)
if sonnet_response:
    print(f"  出力 ({len(sonnet_response)} chars): {sonnet_response[:200]}...")

print("\n── Step 3/3: Gunshi (Opus 4.6) が両者を採点 ──")
haiku_eval  = evaluate(haiku_response,  "Haiku 4.5")
sonnet_eval = evaluate(sonnet_response, "Sonnet 4.6")

haiku_score  = haiku_eval.get('score', 0)
sonnet_score = sonnet_eval.get('score', 0)
diff = sonnet_score - haiku_score

print("\n══ 結果サマリー ══")
print(f"Haiku 4.5  スコア: {haiku_score}/100  (max_bloom=3 で L5タスクは非対応)")
print(f"Sonnet 4.6 スコア: {sonnet_score}/100  (max_bloom=5 で L5タスクは対応)")
print(f"差分:              +{diff}点")
print()

THRESHOLD_SONNET = 70
THRESHOLD_DIFF   = 15
pass_sonnet = sonnet_score >= THRESHOLD_SONNET
pass_diff   = diff >= THRESHOLD_DIFF

print(f"Sonnet ≥ {THRESHOLD_SONNET}点: {'✓ PASS' if pass_sonnet else '✗ FAIL'}")
print(f"差分   ≥ {THRESHOLD_DIFF}点: {'✓ PASS' if pass_diff else '✗ FAIL'}")

verdict = 'PASS' if (pass_sonnet and pass_diff) else 'FAIL'
print(f"\n最終判定: {verdict}")
print(f"（Bloom routing の価値: {'+' if diff > 0 else ''}{diff}点差）")

# ─────────────────────────────────────────────
# レポート保存
# ─────────────────────────────────────────────
report = {
    'dim_d_quality_report': {
        'timestamp': datetime.now().isoformat(),
        'task_bloom_level': 5,
        'task_description': L5_TASK[:200],
        'models': {
            'inappropriate': {
                'model': 'claude-haiku-4-5-20251001',
                'max_bloom': 3,
                'score': haiku_score,
                'evaluation': haiku_eval,
                'response_length': len(haiku_response) if haiku_response else 0,
                'response_preview': (haiku_response or '')[:500],
            },
            'appropriate': {
                'model': 'claude-sonnet-4-6',
                'max_bloom': 5,
                'score': sonnet_score,
                'evaluation': sonnet_eval,
                'response_length': len(sonnet_response) if sonnet_response else 0,
                'response_preview': (sonnet_response or '')[:500],
            },
        },
        'score_diff': diff,
        'thresholds': {
            'sonnet_min': THRESHOLD_SONNET,
            'diff_min':   THRESHOLD_DIFF,
        },
        'pass_sonnet': pass_sonnet,
        'pass_diff':   pass_diff,
        'verdict': verdict,
    }
}

output_path = Path(project_root) / 'queue' / 'reports' / 'dim_d_quality_report.yaml'
output_path.parent.mkdir(parents=True, exist_ok=True)
with open(output_path, 'w') as f:
    yaml.dump(report, f, allow_unicode=True)
print(f"\nレポート保存: {output_path}")

sys.exit(0 if verdict == 'PASS' else 1)
PYEOF
