#!/usr/bin/env bash
# Configure Shogun role CLI types and active ashigaru count.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "  +============================================================+"
echo "  |  [SHOGUN] multi-agent-shogun - Agent Configurator          |"
echo "  |      Choose CLI type per role and active ashigaru count     |"
echo "  +============================================================+"
echo ""

if [[ ! -f "scripts/configure_agents.py" ]]; then
  echo "  [ERROR] scripts/configure_agents.py not found."
  echo "          Run this launcher from the multi-agent-shogun folder."
  exit 1
fi

python3 scripts/configure_agents.py "$@"

echo ""
echo "  [OK] Agent configuration finished."
echo "      Restart runtime with: bash shutsujin_departure.sh -c"
