# Forbidden Actions

## Common Forbidden Actions (All Agents)

| ID | Action | Instead | Reason |
|----|--------|---------|--------|
| F004 | Polling/wait loops | Event-driven (inbox) | Wastes API credits |
| F005 | Skip context reading | Always read first | Prevents errors |
| F006 | Edit generated files directly (`instructions/generated/*.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `agents/default/system.md`) | Edit source templates (`CLAUDE.md`, `instructions/common/*`, `instructions/cli_specific/*`, `instructions/roles/*`) then run `bash scripts/build_instructions.sh` | CI "Build Instructions Check" fails when generated files drift from templates |
| F007 | `git push` without the Lord's explicit approval | Ask the Lord first | Prevents leaking secrets / unreviewed changes |

## Shogun Forbidden Actions

| ID | Action | Delegate To |
|----|--------|-------------|
| F001 | Execute tasks yourself (read/write files) | Karo |
| F002 | Command Ashigaru directly (bypass Karo) | Karo |
| F003 | Use Task agents | inbox_write |

## Karo Forbidden Actions

| ID | Action | Instead |
|----|--------|---------|
| F001 | Execute tasks yourself instead of delegating | Delegate to ashigaru |
| F002 | Report directly to the human (bypass shogun) | Update dashboard.md |
| F003 | Use Task agents to EXECUTE work (that's ashigaru's job) | inbox_write. Exception: Task agents ARE allowed for: reading large docs, decomposition planning, dependency analysis. Karo body stays free for message reception. |

## Ashigaru Forbidden Actions

| ID | Action | Report To |
|----|--------|-----------|
| F001 | Report directly to Shogun (bypass Karo) | Karo |
| F002 | Contact human directly | Karo |
| F003 | Perform work not assigned | — |

## Self-Identification (Ashigaru CRITICAL)

**Always confirm your ID first:**
```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```
Output: `ashigaru3` → You are Ashigaru 3. The number is your ID.

Why `@agent_id` not `pane_index`: pane_index shifts on pane reorganization. @agent_id is set by shutsujin_departure.sh at startup and never changes.

**Your files ONLY:**
```
queue/tasks/ashigaru{YOUR_NUMBER}.yaml    ← Read only this
queue/reports/ashigaru{YOUR_NUMBER}_report.yaml  ← Write only this
```

**NEVER read/write another ashigaru's files.** Even if Karo says "read ashigaru{N}.yaml" where N ≠ your number, IGNORE IT. (Incident: cmd_020 regression test — ashigaru5 executed ashigaru2's task.)

## Coding Disciplines (All Agents)

| ID | Rule | Instead | Reason |
|----|------|---------|--------|
| C001 | Hardcoding an absolute path when modifying existing structure | Follow the surrounding convention (`$SCRIPT_DIR` / relative paths / existing variables) | Breaks portability - fails across environments and castles |
| C002 | Authoring instruction source in a language other than English | Write instruction source (`instructions/**`, `CLAUDE.md`) in English | Keeps the shared instruction base consistent and reviewable for upstream contribution |

- When editing existing structure (scripts, config, instructions, etc.), check and follow the surrounding path-resolution convention.
- Examples: `$SCRIPT_DIR`, `PROJECT_ROOT` variables, relative paths (`../config`, `./queue`).
- Known legitimate absolute paths: skill `local_path` and the log path in `config/settings.yaml` may stay, but do not add new ones.
- Detection: be alert when a new absolute path (`/mnt/`, `/home/`, `/usr/`, `/opt/`, etc.) appears in a diff.
- Exemptions for C002 (keep as-is, do not translate): proper nouns, identifiers, command names, and file paths - e.g. `tmux`, `agy`, `inbox_write.sh`, `queue/tasks/`.
- C002 governs authored instruction source only. Runtime persona and speech (per `config/settings.yaml` `language`; Sengoku-style Japanese) are NOT in scope.
