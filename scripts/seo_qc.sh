#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# SEO Article QC Skill - Wrapper Script
# Usage: bash scripts/seo_qc.sh <site|all> [summary|yaml|both]
# ═══════════════════════════════════════════════════════════════
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE="${1:?Usage: seo_qc.sh <site|all> [summary|yaml|both]}"
OUTPUT="${2:-both}"

python3 "$SCRIPT_DIR/seo_qc.py" "$SITE" --output "$OUTPUT" --report-dir "$SCRIPT_DIR/../queue/reports/"
