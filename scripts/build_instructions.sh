#!/usr/bin/env bash
# ============================================================
# Instruction File Build System
# ============================================================
# Combines instruction parts into complete instruction files
# for each role and CLI combination.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PARTS_DIR="$ROOT_DIR/instructions"
OUTPUT_DIR="$ROOT_DIR/instructions/generated"

mkdir -p "$OUTPUT_DIR"

echo "=== Instruction File Build System ==="
echo "Building instruction files..."

# Function: opencode_build_python
# Description: Returns a Python interpreter with PyYAML for build-time YAML parsing.
# Arguments: none
# Returns: path to python3 on success, 1 on error
opencode_build_python() {
    local candidate
    for candidate in "$ROOT_DIR/.venv/bin/python3" "$(command -v python3 2>/dev/null || true)"; do
        [[ -n "$candidate" && -x "$candidate" ]] || continue
        if "$candidate" -c 'import yaml' 2>/dev/null; then
            echo "$candidate"
            return 0
        fi
    done

    echo "  ❌ PyYAML is required for OpenCode agent generation. Run: python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
    return 1
}

# Function: normalize_generated_markdown
# Description: Normalizes generated markdown so diff hygiene does not depend on source file line endings.
normalize_generated_markdown() {
    local output_path="$1"
    local tmp_path="${output_path}.tmp.$$"

    [ -f "$output_path" ] || return 0

    awk '{ sub(/\r$/, ""); sub(/[ \t]+$/, ""); print }' "$output_path" > "$tmp_path"
    mv "$tmp_path" "$output_path"
}

# ============================================================
# Helper function: Build a complete instruction file
# ============================================================
build_instruction_file() {
    local cli_type="$1"
    local role="$2"
    local output_filename="$3"
    local output_path="$OUTPUT_DIR/$output_filename"
    local original_file="$ROOT_DIR/instructions/${role}.md"

    echo "Building: $output_filename (CLI: $cli_type, Role: $role)"

    # Extract YAML front matter from original file
    if [ -f "$original_file" ]; then
        awk '/^---$/{if(++n==2) {print "---"; exit} if(n==1) next} n==1' "$original_file" > "$output_path"
        echo "" >> "$output_path"
    else
        # Minimal YAML front matter
        cat > "$output_path" <<EOFYAML
---
role: $role
version: "3.0"
cli_type: $cli_type
---

EOFYAML
    fi

    # Append role-specific content
    cat "$PARTS_DIR/roles/${role}_role.md" >> "$output_path"

    # Append common sections
    echo "" >> "$output_path"
    cat "$PARTS_DIR/common/protocol.md" >> "$output_path"
    echo "" >> "$output_path"
    cat "$PARTS_DIR/common/task_flow.md" >> "$output_path"
    echo "" >> "$output_path"
    cat "$PARTS_DIR/common/forbidden_actions.md" >> "$output_path"

    # Append CLI-specific tools section
    echo "" >> "$output_path"
    case "$cli_type" in
        claude)
            cat "$PARTS_DIR/cli_specific/claude_tools.md" >> "$output_path"
            ;;
        codex)
            cat "$PARTS_DIR/cli_specific/codex_tools.md" >> "$output_path"
            ;;
        copilot)
            cat "$PARTS_DIR/cli_specific/copilot_tools.md" >> "$output_path"
            ;;
        kimi)
            cat "$PARTS_DIR/cli_specific/kimi_tools.md" >> "$output_path"
            ;;
        opencode)
            cat "$PARTS_DIR/cli_specific/opencode_tools.md" >> "$output_path"
            ;;
        cursor)
            cat "$PARTS_DIR/cli_specific/cursor_tools.md" >> "$output_path"
            ;;
    esac

    if [[ "$cli_type" == "opencode" ]]; then
        normalize_generated_markdown "$output_path"
    fi

    echo "  ✅ Created: $output_filename"
}

# Build Claude Code instruction files
build_instruction_file "claude" "shogun" "shogun.md"
build_instruction_file "claude" "karo" "karo.md"
build_instruction_file "claude" "ashigaru" "ashigaru.md"
build_instruction_file "claude" "gunshi" "gunshi.md"

# Build Codex instruction files
build_instruction_file "codex" "shogun" "codex-shogun.md"
build_instruction_file "codex" "karo" "codex-karo.md"
build_instruction_file "codex" "ashigaru" "codex-ashigaru.md"
build_instruction_file "codex" "gunshi" "codex-gunshi.md"

# Build Copilot instruction files
build_instruction_file "copilot" "shogun" "copilot-shogun.md"
build_instruction_file "copilot" "karo" "copilot-karo.md"
build_instruction_file "copilot" "ashigaru" "copilot-ashigaru.md"
build_instruction_file "copilot" "gunshi" "copilot-gunshi.md"

# Build Kimi K2 instruction files
build_instruction_file "kimi" "shogun" "kimi-shogun.md"
build_instruction_file "kimi" "karo" "kimi-karo.md"
build_instruction_file "kimi" "ashigaru" "kimi-ashigaru.md"
build_instruction_file "kimi" "gunshi" "kimi-gunshi.md"

# Build OpenCode instruction files
build_instruction_file "opencode" "shogun" "opencode-shogun.md"
build_instruction_file "opencode" "karo" "opencode-karo.md"
build_instruction_file "opencode" "ashigaru" "opencode-ashigaru.md"
build_instruction_file "opencode" "gunshi" "opencode-gunshi.md"

# Build Cursor Agent instruction files
build_instruction_file "cursor" "shogun" "cursor-shogun.md"
build_instruction_file "cursor" "karo" "cursor-karo.md"
build_instruction_file "cursor" "ashigaru" "cursor-ashigaru.md"
build_instruction_file "cursor" "gunshi" "cursor-gunshi.md"

# ============================================================
# AGENTS.md generation (Codex auto-load file)
# ============================================================
# Codex CLIはリポジトリルートのAGENTS.mdを自動読み込みする。
# CLAUDE.mdを正本とし、Claude固有部分をCodex固有に置換して生成。
generate_agents_md() {
    local output_path="$ROOT_DIR/AGENTS.md"
    local claude_md="$ROOT_DIR/CLAUDE.md"

    echo "Generating: AGENTS.md (Codex auto-load)"

    if [ ! -f "$claude_md" ]; then
        echo "  ⚠️  CLAUDE.md not found. Skipping AGENTS.md generation."
        return 1
    fi

    # Normalize line endings to LF to keep tracked auto-load files stable across platforms.
    sed \
        -e 's|CLAUDE\.md|AGENTS.md|g' \
        -e 's|CLAUDE\.local\.md|AGENTS.override.md|g' \
        -e 's|instructions/shogun\.md|instructions/generated/codex-shogun.md|g' \
        -e 's|instructions/karo\.md|instructions/generated/codex-karo.md|g' \
        -e 's|instructions/ashigaru\.md|instructions/generated/codex-ashigaru.md|g' \
        -e 's|instructions/gunshi\.md|instructions/generated/codex-gunshi.md|g' \
        -e 's|~/.claude/|~/.codex/|g' \
        -e 's|\.claude\.json|.codex/config.toml|g' \
        -e 's|\.mcp\.json|config.toml (mcp_servers section)|g' \
        -e 's|Claude Code|Codex CLI|g' \
        -e 's|## /clear Recovery|## /new Recovery|g' \
        -e 's|Forbidden after /clear|Forbidden after /new|g' \
        -e 's|pre-/clear memory|pre-/new memory|g' \
        -e 's|lost on /clear)|lost on /new)|g' \
        -e 's|(/new or /clear)|(`/new`)|g' \
        -e 's|sends `/clear` + Enter via send-keys|sends `/new` + Enter via send-keys（/clear→/new自動変換）|g' \
        -e 's|`/clear` sent (max once per 5 min)|スキップ（Codexは`/clear`不可）|g' \
        -e 's|escalation sends `/clear` (~4 min)|next nudge escalation or task reassignment|g' \
        -e 's|delivers `/clear` to the agent|delivers `/new` to the agent（/clear→/new自動変換）|g' \
        -e 's|`/clear` wipes old context|`/new` wipes old context|g' \
        "$claude_md" | tr -d '\r' > "$output_path"

    echo "  ✅ Created: AGENTS.md"
}

# ============================================================
# copilot-instructions.md generation (Copilot auto-load file)
# ============================================================
# GitHub Copilot CLIは .github/copilot-instructions.md を自動読み込みする。
# CLAUDE.mdを正本とし、Claude固有部分をCopilot固有に置換して生成。
generate_copilot_instructions() {
    local github_dir="$ROOT_DIR/.github"
    local output_path="$github_dir/copilot-instructions.md"
    local claude_md="$ROOT_DIR/CLAUDE.md"

    echo "Generating: .github/copilot-instructions.md (Copilot auto-load)"

    if [ ! -f "$claude_md" ]; then
        echo "  ⚠️  CLAUDE.md not found. Skipping copilot-instructions.md generation."
        return 1
    fi

    mkdir -p "$github_dir"

    # Normalize line endings to LF to keep tracked auto-load files stable across platforms.
    sed \
        -e 's|CLAUDE\.md|copilot-instructions.md|g' \
        -e 's|CLAUDE\.local\.md|copilot-instructions.local.md|g' \
        -e 's|instructions/shogun\.md|instructions/generated/copilot-shogun.md|g' \
        -e 's|instructions/karo\.md|instructions/generated/copilot-karo.md|g' \
        -e 's|instructions/ashigaru\.md|instructions/generated/copilot-ashigaru.md|g' \
        -e 's|instructions/gunshi\.md|instructions/generated/copilot-gunshi.md|g' \
        -e 's|~/.claude/|~/.copilot/|g' \
        -e 's|\.claude\.json|.copilot/config.json|g' \
        -e 's|\.mcp\.json|.copilot/mcp-config.json|g' \
        -e 's|Claude Code|GitHub Copilot CLI|g' \
        "$claude_md" | tr -d '\r' > "$output_path"

    echo "  ✅ Created: .github/copilot-instructions.md"
}

# ============================================================
# Kimi K2 auto-load files generation
# ============================================================
# Kimi K2 CLIは agents/default/agent.yaml + system.md を自動読み込みする。
# CLAUDE.mdを正本とし、Claude固有部分をKimi固有に置換して生成。
generate_kimi_instructions() {
    local agents_dir="$ROOT_DIR/agents/default"
    local system_md_path="$agents_dir/system.md"
    local agent_yaml_path="$agents_dir/agent.yaml"
    local claude_md="$ROOT_DIR/CLAUDE.md"

    echo "Generating: agents/default/system.md + agent.yaml (Kimi auto-load)"

    if [ ! -f "$claude_md" ]; then
        echo "  ⚠️  CLAUDE.md not found. Skipping Kimi auto-load generation."
        return 1
    fi

    mkdir -p "$agents_dir"

    # Generate system.md (CLAUDE.md → Kimi版)
    # Normalize line endings to LF to keep tracked auto-load files stable across platforms.
    sed \
        -e 's|CLAUDE\.md|agents/default/system.md|g' \
        -e 's|CLAUDE\.local\.md|agents/default/system.local.md|g' \
        -e 's|instructions/shogun\.md|instructions/generated/kimi-shogun.md|g' \
        -e 's|instructions/karo\.md|instructions/generated/kimi-karo.md|g' \
        -e 's|instructions/ashigaru\.md|instructions/generated/kimi-ashigaru.md|g' \
        -e 's|instructions/gunshi\.md|instructions/generated/kimi-gunshi.md|g' \
        -e 's|~/.claude/|~/.kimi/|g' \
        -e 's|\.claude\.json|.kimi/config.json|g' \
        -e 's|\.mcp\.json|.kimi/mcp.json|g' \
        -e 's|Claude Code|Kimi K2 CLI|g' \
        "$claude_md" | tr -d '\r' > "$system_md_path"

    echo "  ✅ Created: agents/default/system.md"

    # Generate agent.yaml (Kimi agent definition)
    cat > "$agent_yaml_path" <<'EOFYAML'
# Kimi K2 Agent Configuration
# Auto-generated by build_instructions.sh — do not edit manually
name: multi-agent-shogun
description: "Kimi K2 CLI agent for multi-agent-shogun system"
model: moonshot-k2.5
system_prompt_file: system.md
tools:
  - file_read
  - file_write
  - shell_exec
  - web_search
EOFYAML

    echo "  ✅ Created: agents/default/agent.yaml"
}

# ============================================================
# OpenCode agent definition files generation
# ============================================================
# OpenCode reads .opencode/agents/<name>.md and uses the YAML
# frontmatter + body as a built-in system prompt.  This replaces
# the former --prompt bootstrap approach.  Permissions are
# expanded from config/opencode-permissions.yaml at build time
# so that OPENCODE_CONFIG_CONTENT is no longer needed at launch.

# Function: generate_opencode_agents
# Description: Generates .opencode/agents/*.md files with role frontmatter and OpenCode-specific rules.
# Arguments: none
# Returns: 0 on success, 1 if generation is skipped or unavailable
generate_opencode_agents() {
    local agents_dir="$ROOT_DIR/.opencode/agents"
    local permissions_file="${OPENCODE_PERMISSIONS_FILE:-$ROOT_DIR/config/opencode-permissions.yaml}"
    local python_bin

    echo "Generating: .opencode/agents/*.md (OpenCode agent definitions)"

    if [ ! -f "$permissions_file" ]; then
        echo "  ⚠️  config/opencode-permissions.yaml not found. Skipping OpenCode agent generation."
        return 1
    fi

    mkdir -p "$agents_dir"

    python_bin=$(opencode_build_python) || {
        echo "  ❌ Python with PyYAML not found. Cannot generate OpenCode agents." >&2
        return 1
    }

    # Agent ID → role mapping.  Keep this tracked output deterministic: do not
    # derive generated file names from git-ignored config/settings.yaml or
    # runtime queue/tasks state.
    local agent_ids
    agent_ids="shogun karo gunshi ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7"

    for agent_id in $agent_ids; do
        # Determine role (all ashigaru share the same role template)
        local role=""
        case "$agent_id" in
            ashigaru*) role="ashigaru" ;;
            *)         role="$agent_id" ;;
        esac

        # Determine role title for description
        local role_title=""
        case "$agent_id" in
            shogun)
                role_title="Shogun — strategic oversight and command issuance"
                ;;
            karo)
                role_title="Karo — task decomposition, assignment, and coordination"
                ;;
            gunshi)
                role_title="Gunshi — strategic analysis and quality control"
                ;;
            ashigaru*)
                local ashigaru_number="${agent_id#ashigaru}"
                role_title="Ashigaru ${ashigaru_number} — front-line execution"
                ;;
        esac

        # Generate permission YAML via the same Python logic used in cli_adapter.sh
        local permission_yaml
        if ! permission_yaml=$("$python_bin" - "$permissions_file" "$agent_id" <<'PYEOF'
import json, sys, yaml

permissions_file = sys.argv[1]
agent_id = sys.argv[2]

def role_for_agent(agent_id: str) -> str:
    if agent_id.startswith('ashigaru'):
        return 'ashigaru'
    if agent_id in {'shogun', 'karo', 'gunshi'}:
        return agent_id
    return ''

def expand(pattern: str) -> str:
    return pattern.replace('{agent_id}', agent_id)

def build_rule(deny_patterns, allow_patterns):
    deny = []
    allow = []
    seen = set()
    for pattern in deny_patterns or []:
        expanded = expand(pattern)
        if expanded not in seen:
            seen.add(expanded)
            deny.append(expanded)
    for pattern in allow_patterns or []:
        expanded = expand(pattern)
        if expanded not in seen:
            seen.add(expanded)
            allow.append(expanded)
    rule = {}
    for pattern in deny:
        rule[pattern] = 'deny'
    for pattern in allow:
        rule[pattern] = 'allow'
    return rule

with open(permissions_file, encoding='utf-8') as fh:
    config = yaml.safe_load(fh) or {}

role = role_for_agent(agent_id)
roles = config.get('roles') or {}
role_cfg = roles.get(role) or {}

common_edit_deny = list((config.get('common') or {}).get('edit_deny') or [])
read_rule = build_rule(role_cfg.get('read_deny'), role_cfg.get('read_allow'))
edit_rule = build_rule(common_edit_deny + list(role_cfg.get('edit_deny') or []), role_cfg.get('edit_allow'))

permission = {
    '*': 'allow',
    'question': role_cfg.get('question', 'deny'),
    'read': read_rule,
    'edit': edit_rule,
    'write': edit_rule,
    'patch': edit_rule,
    'list': read_rule,
    'glob': read_rule,
}

# Intentionally do not generate per-path `grep` permissions. OpenCode matches
# `grep` permission rules against the search regex, not the target file path, so
# reusing read_rule here would look restrictive while not enforcing role file
# boundaries. `grep` therefore inherits the top-level `*: allow`, matching the
# permissive execution model used by the existing yolo-style CLI integrations.

# Output as YAML (indented) for embedding in frontmatter
print(yaml.dump({'permission': permission}, default_flow_style=False, allow_unicode=True).rstrip())
PYEOF
        ); then
            echo "  ❌ Failed to generate OpenCode permissions for ${agent_id}" >&2
            return 1
        fi

        local routing_yaml
        routing_yaml=$("$python_bin" - "$ROOT_DIR/config/settings.yaml" "$agent_id" <<'PYEOF'
import sys
from pathlib import Path

import yaml

settings_path = Path(sys.argv[1])
agent_id = sys.argv[2]

def normalize_opencode_model(model: str) -> str:
    if not model:
        return ""
    if "/" in model:
        return model
    if model in {"gpt-5.4-mini", "gpt-5.4", "gpt-5.3-codex", "gpt-5.3-codex-spark"} or model.startswith("gpt-5"):
        return f"openai/{model}"
    if model in {"claude-opus-4-6", "opus"}:
        return "anthropic/claude-opus-4-6"
    if model in {"claude-sonnet-4-6", "sonnet"}:
        return "anthropic/claude-sonnet-4-6"
    if model in {"claude-haiku-4-5-20251001", "haiku"}:
        return "anthropic/claude-haiku-4-5-20251001"
    if model in {"moonshot-k2.5", "k2.5"}:
        return "moonshot/kimi-k2.5"
    if model.startswith("kimi-"):
        return f"moonshot/kimi-{model.removeprefix('kimi-')}"
    return model

def default_model_for(agent: str) -> str:
    if agent == "shogun":
        return "opus"
    if agent == "karo":
        return "sonnet"
    if agent == "gunshi":
        return "opus"
    return "sonnet"

if not settings_path.exists():
    raise SystemExit(0)

with settings_path.open(encoding="utf-8") as fh:
    settings = yaml.safe_load(fh) or {}

cli = settings.get("cli") or {}
default_cli = cli.get("default", "claude")
agents = cli.get("agents") or {}
agent_cfg = agents.get(agent_id)

agent_type = default_cli
model = None
variant = None

if isinstance(agent_cfg, str):
    agent_type = agent_cfg
elif isinstance(agent_cfg, dict):
    agent_type = agent_cfg.get("type") or default_cli
    model = agent_cfg.get("model")
    variant = agent_cfg.get("variant")

if agent_type != "opencode":
    raise SystemExit(0)

if not model:
    models = settings.get("models") or {}
    model = models.get(agent_id) or default_model_for(agent_id)

frontmatter = {"model": normalize_opencode_model(str(model))}
if variant:
    frontmatter["variant"] = str(variant)

print(yaml.safe_dump(frontmatter, allow_unicode=True, sort_keys=False).rstrip())
PYEOF
        )

        local output_path="$agents_dir/${agent_id}.md"

        # Write YAML frontmatter
        cat > "$output_path" <<FRONTMATTER
---
description: "${role_title}"
mode: primary
# Auto-generated by build_instructions.sh — do not edit manually.
# Source: instructions/roles/${role}_role.md + instructions/common/* + instructions/cli_specific/opencode_tools.md
# grep intentionally inherits '*: allow'; OpenCode grep permission rules match the search regex, not file paths.
${permission_yaml}
---

FRONTMATTER

        # Append role-specific content (same pipeline as build_instruction_file)
        {
            cat "$PARTS_DIR/roles/${role}_role.md"

            echo ""
            cat <<EOF
## Identity Anchor

This generated file belongs to exactly one agent.

- Canonical agent_id: \`${agent_id}\`
- Canonical tmux check: \`tmux display-message -t "\$TMUX_PANE" -p '#{@agent_id}'\`
- Proceed only if the tmux value matches the canonical agent_id.
- If you have not confirmed this yet, confirm it before reading inbox/task files.

EOF

            # Append common sections
            echo ""
            cat "$PARTS_DIR/common/protocol.md"
            echo ""
            cat "$PARTS_DIR/common/task_flow.md"
            echo ""
            cat "$PARTS_DIR/common/forbidden_actions.md"

            # Append OpenCode-specific tools section
            echo ""
            cat "$PARTS_DIR/cli_specific/opencode_tools.md"
        } >> "$output_path"

        normalize_generated_markdown "$output_path"

        if [[ -n "$routing_yaml" ]]; then
            local runtime_path="$agents_dir/${agent_id}-runtime.md"
            ROUTING_YAML="$routing_yaml" "$python_bin" - "$output_path" "$runtime_path" <<'PYEOF'
import os
import sys
from pathlib import Path

import yaml

source = Path(sys.argv[1])
dest = Path(sys.argv[2])
route = yaml.safe_load(os.environ.get("ROUTING_YAML", "")) or {}

text = source.read_text(encoding="utf-8")
if not text.startswith("---\n"):
    raise SystemExit(0)

parts = text.split("---", 2)
if len(parts) < 3:
    raise SystemExit(0)

route_lines = yaml.safe_dump(route, allow_unicode=True, sort_keys=False).splitlines()
frontmatter_lines = parts[1].lstrip("\n").splitlines()
new_lines = []
inserted = False

for line in frontmatter_lines:
    stripped = line.lstrip()
    indent = len(line) - len(stripped)
    if indent == 0 and (stripped.startswith("model:") or stripped.startswith("variant:")):
        continue
    if not inserted and indent == 0 and stripped.startswith("permission:"):
        new_lines.extend(route_lines)
        inserted = True
    new_lines.append(line)

if not inserted:
    new_lines.extend(route_lines)

dest.write_text(f"---\n{chr(10).join(new_lines).rstrip()}\n---{parts[2]}", encoding="utf-8")
PYEOF
            normalize_generated_markdown "$runtime_path"
            echo "  ✅ Created: .opencode/agents/${agent_id}-runtime.md (git-ignored runtime routing)"
        fi

        echo "  ✅ Created: .opencode/agents/${agent_id}.md"
    done
}

# Generate CLI auto-load files
generate_agents_md
generate_copilot_instructions
generate_kimi_instructions
generate_opencode_agents

echo ""
echo "=== Build Complete ==="
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Generated instruction files:"
ls -lh "$OUTPUT_DIR"/*.md
echo ""
echo "CLI auto-load files:"
[ -f "$ROOT_DIR/AGENTS.md" ] && ls -lh "$ROOT_DIR/AGENTS.md"
[ -f "$ROOT_DIR/.github/copilot-instructions.md" ] && ls -lh "$ROOT_DIR/.github/copilot-instructions.md"
[ -f "$ROOT_DIR/agents/default/system.md" ] && ls -lh "$ROOT_DIR/agents/default/system.md"
[ -f "$ROOT_DIR/agents/default/agent.yaml" ] && ls -lh "$ROOT_DIR/agents/default/agent.yaml"
echo ""
echo "OpenCode agent definitions:"
ls -lh "$ROOT_DIR/.opencode/agents/"*.md 2>/dev/null || echo "  (none)"
