#!/usr/bin/env bash
# macOS Finder launcher for Shogun agent configuration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "  +============================================================+"
echo "  |  [SHOGUN] multi-agent-shogun - Agent Configurator          |"
echo "  |      Choose CLI type per role and active ashigaru count     |"
echo "  +============================================================+"
echo ""

if [[ ! -f "scripts/configure_agents.py" ]]; then
  echo "  [ERROR] scripts/configure_agents.py not found."
  echo "          Put this .command file in the multi-agent-shogun folder."
  echo ""
  read -r -p "Press Enter to close..."
  exit 1
fi

python3 scripts/configure_agents.py "$@"

echo ""
echo "  [OK] Agent configuration finished."
echo "      Restart runtime with: bash shutsujin_departure.sh -c"
echo ""
read -r -p "Press Enter to close..."
