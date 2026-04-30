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
    esac

    echo "  ✅ Created: $output_filename"
}

# Build Claude Code instruction files
build_instruction_file "claude" "orchestrator" "orchestrator.md"
build_instruction_file "claude" "planner" "planner.md"
build_instruction_file "claude" "engineer" "engineer.md"
build_instruction_file "claude" "reviewer" "reviewer.md"

# Build Codex instruction files
build_instruction_file "codex" "orchestrator" "codex-orchestrator.md"
build_instruction_file "codex" "planner" "codex-planner.md"
build_instruction_file "codex" "engineer" "codex-engineer.md"
build_instruction_file "codex" "reviewer" "codex-reviewer.md"

# Build Copilot instruction files
build_instruction_file "copilot" "orchestrator" "copilot-orchestrator.md"
build_instruction_file "copilot" "planner" "copilot-planner.md"
build_instruction_file "copilot" "engineer" "copilot-engineer.md"
build_instruction_file "copilot" "reviewer" "copilot-reviewer.md"

# Build Kimi K2 instruction files
build_instruction_file "kimi" "orchestrator" "kimi-orchestrator.md"
build_instruction_file "kimi" "planner" "kimi-planner.md"
build_instruction_file "kimi" "engineer" "kimi-engineer.md"
build_instruction_file "kimi" "reviewer" "kimi-reviewer.md"

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
        -e 's|instructions/orchestrator.md|instructions/generated/codex-orchestrator.md|g' \
        -e 's|instructions/planner.md|instructions/generated/codex-planner.md|g' \
        -e 's|instructions/engineer.md|instructions/generated/codex-engineer.md|g' \
        -e 's|instructions/reviewer.md|instructions/generated/codex-reviewer.md|g' \
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
        -e 's|instructions/orchestrator.md|instructions/generated/copilot-orchestrator.md|g' \
        -e 's|instructions/planner.md|instructions/generated/copilot-planner.md|g' \
        -e 's|instructions/engineer.md|instructions/generated/copilot-engineer.md|g' \
        -e 's|instructions/reviewer.md|instructions/generated/copilot-reviewer.md|g' \
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
        -e 's|instructions/orchestrator.md|instructions/generated/kimi-orchestrator.md|g' \
        -e 's|instructions/planner.md|instructions/generated/kimi-planner.md|g' \
        -e 's|instructions/engineer.md|instructions/generated/kimi-engineer.md|g' \
        -e 's|instructions/reviewer.md|instructions/generated/kimi-reviewer.md|g' \
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
name: multi-agent-orchestrator
description: "Kimi K2 CLI agent for multi-agent-orchestrator system"
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

# Generate CLI auto-load files
generate_agents_md
generate_copilot_instructions
generate_kimi_instructions

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
