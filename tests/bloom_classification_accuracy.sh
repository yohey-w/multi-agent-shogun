#!/usr/bin/env bash
# bloom_classification_accuracy.sh — Dim B: Bloom分類精度テスト
# Usage: bash tests/bloom_classification_accuracy.sh [--corpus path] [--output path] [--agent ashigaru_id]
#
# bloom_task_corpus.yaml の各タスクをGunshiに送り、
# 分類されたBloomレベルを expected_bloom と比較して精度を測定する。
#
# 合格基準:
#   exact match  >= 60%  (完全一致)
#   tolerance    >= 80%  (±1レベル許容)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORPUS="${1:-${PROJECT_ROOT}/tests/fixtures/bloom_task_corpus.yaml}"
OUTPUT="${PROJECT_ROOT}/queue/reports/bloom_accuracy_report.yaml"
GUNSHI_TASK_FILE="${PROJECT_ROOT}/queue/tasks/gunshi.yaml"
GUNSHI_REPORT="${PROJECT_ROOT}/queue/reports/gunshi_bloom_test.yaml"

# 引数パース
while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus) CORPUS="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --help) echo "Usage: $0 [--corpus path] [--output path]"; exit 0 ;;
        *) shift ;;
    esac
done

echo "══ Bloom分類精度テスト ══"
echo "コーパス: $CORPUS"
echo "出力先:   $OUTPUT"
echo ""

if [[ ! -f "$CORPUS" ]]; then
    echo "エラー: コーパスファイルが見つからない: $CORPUS" >&2
    exit 1
fi

# Python で corpus を読み込んで各タスクを処理
python3 << PYEOF
import yaml, subprocess, re, sys, json, os
from pathlib import Path
from datetime import datetime

corpus_path = "${CORPUS}"
output_path = "${OUTPUT}"
project_root = "${PROJECT_ROOT}"
gunshi_task_file = "${GUNSHI_TASK_FILE}"
gunshi_report_file = "${GUNSHI_REPORT}"

with open(corpus_path) as f:
    corpus = yaml.safe_load(f)

tasks = corpus.get('bloom_tasks', [])
total = len(tasks)
exact_match = 0
tolerance_match = 0
results = []

confusion = {}  # expected -> {got: count}

print(f"全 {total} タスクを処理中...")
print()

for task in tasks:
    task_id = task['id']
    expected = task['bloom_level']
    description = task['description'].strip()

    print(f"[{task_id}] expected=L{expected} | {description[:60]}...")

    # Gunshiへのタスクを書く
    task_yaml = {
        'task': {
            'task_id': f'bloom_test_{task_id}',
            'bloom_level': 'L2',  # このタスク自体はL2（説明タスク）
            'description': f'''Bloomレベル判定テスト。
以下のタスクが認知レベル（ブルームタクソノミー）のどのレベルに該当するか判定せよ。
1-6の数値のみを返せ。説明不要。数値のみ。

タスク:
{description}''',
            'status': 'assigned',
            'timestamp': datetime.now().isoformat(),
        }
    }

    with open(gunshi_task_file, 'w') as f:
        yaml.dump(task_yaml, f, allow_unicode=True)

    # Gunshiへinbox_write（テスト実行中はシミュレート）
    # 実際のVPS E2Eではここでinbox_writeを呼んで回答待ちになる
    # このスクリプトは「バッチ判定」モード: direct CLIコールでシミュレート

    # *** VPS実行時: 以下のコメントアウトを外してGunshiに実際に問い合わせる ***
    # inbox_cmd = f"bash {project_root}/scripts/inbox_write.sh gunshi 'bloom_test_{task_id} の判定を実施せよ' task_assigned karo"
    # subprocess.run(inbox_cmd, shell=True, cwd=project_root)
    # got = wait_for_gunshi_response(task_id)  # 実装が必要

    # *** ローカル検証モード: Claudeに直接問い合わせる（claude CLIが必要）***
    # claude CLIのパスを動的に解決（PATH未設定環境対応）
    claude_cmd = subprocess.run(['which', 'claude'], capture_output=True, text=True).stdout.strip()
    if not claude_cmd:
        import glob as _glob
        candidates = _glob.glob(os.path.expanduser('~/.local/bin/claude')) + \
                     _glob.glob(os.path.expanduser('~/.npm-global/bin/claude')) + \
                     _glob.glob('/usr/local/bin/claude')
        claude_cmd = next((c for c in candidates if os.path.isfile(c)), 'claude')
    try:
        result = subprocess.run(
            [claude_cmd, '-p', f'''このタスクの認知レベル（Bloomの分類法、1-6）を数値1つで答えよ。
説明不要、数値のみ返せ。

タスク説明:
{description}

レベル定義:
1=記憶(Remember), 2=理解(Understand), 3=応用(Apply),
4=分析(Analyze), 5=評価(Evaluate), 6=創造(Create)'''],
            capture_output=True, text=True, timeout=60
        )
        response = result.stdout.strip()
        # 数値を抽出
        nums = re.findall(r'[1-6]', response)
        got = int(nums[0]) if nums else None
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception) as e:
        got = None
        print(f"  WARNING: Claude CLIエラー: {e}")

    # スコア計算
    exact = (got == expected) if got is not None else False
    within1 = (abs(got - expected) <= 1) if got is not None else False

    if exact:
        exact_match += 1
        status = "✓ EXACT"
    elif within1:
        tolerance_match += 1
        status = "~ WITHIN1"
    else:
        status = "✗ MISS"

    if got is not None:
        confusion.setdefault(expected, {})
        confusion[expected][got] = confusion[expected].get(got, 0) + 1

    print(f"  got=L{got}  {status}")
    results.append({
        'task_id': task_id,
        'expected_bloom': expected,
        'got_bloom': got,
        'exact': exact,
        'within1': within1,
    })

# 集計
valid = [r for r in results if r['got_bloom'] is not None]
valid_count = len(valid)
if valid_count > 0:
    exact_rate = sum(1 for r in valid if r['exact']) / valid_count * 100
    tolerance_rate = sum(1 for r in valid if r['within1'] or r['exact']) / valid_count * 100
else:
    exact_rate = tolerance_rate = 0.0

pass_exact = exact_rate >= 60
pass_tolerance = tolerance_rate >= 80

print()
print("══ 結果サマリー ══")
print(f"有効回答: {valid_count}/{total}")
print(f"完全一致率: {exact_rate:.1f}%  {'✓ PASS' if pass_exact else '✗ FAIL'} (基準 ≥60%)")
print(f"±1許容率:  {tolerance_rate:.1f}%  {'✓ PASS' if pass_tolerance else '✗ FAIL'} (基準 ≥80%)")
print()
print("混同行列 (expected → got):")
for expected_level in sorted(confusion.keys()):
    row = confusion[expected_level]
    print(f"  L{expected_level}: " + " | ".join(f"L{k}:{v}" for k, v in sorted(row.items())))

# 出力YAML
report = {
    'bloom_accuracy_report': {
        'timestamp': datetime.now().isoformat(),
        'corpus': corpus_path,
        'total_tasks': total,
        'valid_responses': valid_count,
        'exact_match_rate': round(exact_rate, 1),
        'tolerance_match_rate': round(tolerance_rate, 1),
        'pass_exact': pass_exact,
        'pass_tolerance': pass_tolerance,
        'verdict': 'PASS' if (pass_exact and pass_tolerance) else 'FAIL',
        'results': results,
        'confusion_matrix': {str(k): v for k, v in confusion.items()},
    }
}

Path(output_path).parent.mkdir(parents=True, exist_ok=True)
with open(output_path, 'w') as f:
    yaml.dump(report, f, allow_unicode=True)

print(f"\nレポート保存: {output_path}")

verdict = 'PASS' if (pass_exact and pass_tolerance) else 'FAIL'
print(f"\n最終判定: {verdict}")
sys.exit(0 if verdict == 'PASS' else 1)
PYEOF
