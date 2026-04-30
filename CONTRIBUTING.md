# Contributing to multi-agent-shogun

Thank you for your interest in contributing to multi-agent-shogun! This document provides guidelines for contributing to the project.

## Table of Contents

1. [How to Contribute](#how-to-contribute)
2. [Project Structure](#project-structure)
3. [.gitignore Whitelist Approach](#gitignore-whitelist-approach)
4. [Coding Conventions](#coding-conventions)
5. [Testing](#testing)
6. [Pull Request Guidelines](#pull-request-guidelines)
7. [Communication](#communication)

---

## How to Contribute

### Fork, Branch, PR Workflow

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/multi-agent-shogun.git
   cd multi-agent-shogun
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes** and commit them with clear, descriptive messages
5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
6. **Open a Pull Request** on GitHub

### Before You Start

- Check existing [Issues](https://github.com/yohey-w/multi-agent-shogun/issues) to avoid duplicate work
- For major changes, open a [Discussion](https://github.com/yohey-w/multi-agent-shogun/discussions) first
- Read this entire document to understand our conventions and requirements

---

## Project Structure

Understanding the directory layout will help you navigate the codebase:

```
multi-agent-shogun/
│
├── scripts/              # Core utility scripts
│   ├── inbox_write.sh    # Agent-to-agent messaging (file-based mailbox)
│   ├── inbox_watcher.sh  # Event-driven delivery via inotifywait
│   ├── ntfy.sh           # Push notifications to phone
│   └── build_instructions.sh  # Generate CLI-specific instructions
│
├── instructions/         # Agent behavior definitions
│   ├── shogun.md         # Shogun (commander) instructions
│   ├── karo.md           # Karo (manager) instructions
│   ├── ashigaru.md       # Ashigaru (worker) instructions
│   ├── cli_specific/     # CLI-specific tool descriptions
│   │   ├── claude_tools.md
│   │   ├── codex_tools.md
│   │   └── copilot_tools.md
│   └── generated/        # Built from templates (do not edit manually)
│
├── lib/                  # Core libraries
│   └── cli_adapter.sh    # Multi-CLI abstraction layer
│
├── templates/            # Report and context templates
│   ├── context_template.md  # Universal 7-section project context
│   └── integ_*.md        # Integration report templates
│
├── queue/                # Communication and task data
│   ├── shogun_to_karo.yaml  # Command queue
│   ├── inbox/            # Per-agent mailboxes
│   ├── tasks/            # Per-worker task assignments
│   └── reports/          # Completion reports
│
├── config/               # Configuration files
│   ├── settings.yaml     # Language, CLI settings, ntfy topic
│   └── projects.yaml     # Project registry
│
├── tests/                # Test suite
│   ├── unit/             # bats unit tests
│   └── integration/      # bats integration tests
│
├── docs/                 # Documentation
│   └── philosophy.md     # Design principles
│
├── .github/
│   └── workflows/        # CI/CD pipelines
│       └── test.yml      # GitHub Actions test suite
│
├── shutsujin_departure.sh  # Daily deployment script
├── first_setup.sh          # First-time setup
├── CLAUDE.md               # Core system instructions (auto-loaded)
├── AGENTS.md               # Codex auto-load file
└── Makefile                # Development commands
```

### Key Directories

| Directory | Purpose | Important Notes |
|-----------|---------|-----------------|
| `scripts/` | Core system utilities | All scripts must pass shellcheck |
| `instructions/` | Agent behavior | CLI-specific instructions go in `cli_specific/` |
| `lib/` | Shared libraries | `cli_adapter.sh` handles CLI abstraction |
| `queue/` | Runtime data | Git-ignored, generated at runtime |
| `templates/` | Reusable templates | Used for reports and context files |
| `tests/` | Test suite | bats format, organized by level (unit/integration) |

---

## .gitignore Whitelist Approach

**CRITICAL:** This project uses a **whitelist-based .gitignore** strategy.

### How It Works

1. **Step 1**: Default `*` excludes everything from git
2. **Step 2**: `!*/` allows directory traversal
3. **Step 3**: Individual files and directories are explicitly allowed with `!filename`

### Adding New Files to Git

**Before adding a new file to git, you MUST add it to the .gitignore whitelist:**

```bash
# Example: Adding a new script to git

# 1. Create your file
touch scripts/new_script.sh

# 2. Edit .gitignore and add the whitelist entry
echo '!scripts/new_script.sh' >> .gitignore

# 3. Now git will track it
git add scripts/new_script.sh
git commit -m "feat: add new_script.sh"
```

### What Gets Excluded by Default

The following are intentionally excluded (do NOT whitelist these):

- `projects/` — Contains confidential client information
- `queue/` — Runtime data, generated dynamically
- `memory/` — User-specific persistent memory
- `.claude/commands/` — User-specific skills (not committed)
- `saytask/streaks.yaml` — User-specific task data

### Checking Before Commit

```bash
# Verify your new file is tracked
git status

# If your file doesn't appear, check .gitignore
grep "your_file_name" .gitignore
```

---

## Coding Conventions

### Shell Scripts

All shell scripts must adhere to these standards:

1. **Shellcheck compliance**
   ```bash
   # Run shellcheck before committing
   make lint
   ```
   - Fix all warnings and errors
   - Use `# shellcheck disable=SCXXXX` only when absolutely necessary (with explanation)

2. **Shebang line**
   ```bash
   #!/usr/bin/env bash
   ```

3. **Error handling**
   ```bash
   set -euo pipefail  # Exit on error, undefined vars, pipe failures
   ```

4. **Function documentation**
   ```bash
   # Function: send_message
   # Description: Writes a message to an agent's inbox
   # Arguments:
   #   $1 - target_agent (shogun|karo|ashigaru1-8)
   #   $2 - message content
   # Returns: 0 on success, 1 on error
   send_message() {
       local target_agent="$1"
       local message="$2"
       # ... implementation
   }
   ```

5. **Variable naming**
   - `UPPERCASE` for constants and environment variables
   - `lowercase` for local variables
   - Use `local` for function-scoped variables

6. **Quoting**
   ```bash
   # Always quote variables to prevent word splitting
   echo "$VARIABLE"         # Good
   echo $VARIABLE           # Bad

   # Quote paths with spaces
   cd "$PROJECT_PATH"       # Good
   cd $PROJECT_PATH         # Bad
   ```

### YAML Files

1. **Indentation**: 2 spaces (no tabs)
2. **Booleans**: Use `true`/`false` (lowercase)
3. **Strings**: Quote when necessary, avoid excessive quoting
4. **Comments**: Use `#` for inline explanations

Example:
```yaml
# Task assignment for ashigaru1
task:
  task_id: subtask_001
  description: "Research React 19 features"
  status: assigned
  blockedBy: []  # No dependencies
```

### Markdown Files

1. **Line length**: No hard limit, but aim for readability (80-120 chars for prose)
2. **Headers**: Use ATX-style (`#` prefix)
3. **Code blocks**: Always specify language for syntax highlighting
4. **Links**: Use reference-style for repeated links

---

## Testing

### Test Levels

The project uses a three-tier testing strategy:

| Level | Type | Tool | Location | Run Command |
|-------|------|------|----------|-------------|
| L1 | Unit | bats | `tests/unit/` | `make test` |
| L2 | Integration | bats | `tests/integration/` | `make test-int` |
| L3 | End-to-End | Manual | N/A | Karo executes |

### SKIP = FAIL Policy

**CRITICAL RULE**: A test with SKIP count >= 1 is considered FAILED.

- Tests must either run or explicitly fail
- Do NOT report completion if tests were skipped
- Check prerequisites before running tests

### Running Tests

```bash
# Install test dependencies (first time only)
make install-deps

# Run unit tests
make test

# Run integration tests (Claude Code only)
make test-int

# Run shellcheck linter
make lint

# Build + diff check (CI equivalent)
make check
```

### Writing Tests

All tests use **bats** (Bash Automated Testing System):

```bash
#!/usr/bin/env bats
# test_example.bats

setup() {
    # Setup code runs before each test
    TEST_TMP="$(mktemp -d)"
}

teardown() {
    # Cleanup code runs after each test
    rm -rf "$TEST_TMP"
}

@test "inbox_write.sh creates inbox file" {
    run bash scripts/inbox_write.sh karo "test message" cmd_new shogun
    [ "$status" -eq 0 ]
    [ -f "queue/inbox/karo.yaml" ]
}
```

### Test Guidelines

1. **Preflight checks**: Verify all prerequisites before running tests
   ```bash
   @test "check tmux is installed" {
       command -v tmux || skip "tmux not installed"
   }
   ```

2. **Isolation**: Tests must not interfere with each other
   - Use temporary directories (`mktemp -d`)
   - Clean up after each test in `teardown()`

3. **Assertions**: Use bats-assert for clear error messages
   ```bash
   load 'test_helper/bats-assert/load'

   @test "example assertion" {
       run some_command
       assert_success
       assert_output --partial "expected text"
   }
   ```

4. **E2E tests**: Only Karo can execute E2E tests (requires multi-agent control)

---

## Pull Request Guidelines

### Before Submitting

- [ ] All tests pass (`make test`, `make test-int`)
- [ ] Shellcheck passes (`make lint`)
- [ ] Generated instructions are in sync (`make check`)
- [ ] New files are added to `.gitignore` whitelist
- [ ] Commits have clear, descriptive messages
- [ ] Documentation is updated (if applicable)

### PR Title Format

Use conventional commit prefixes:

```
feat: add new CLI adapter for Kimi Code
fix: resolve inbox_watcher rc=1 on atomic writes
docs: update CONTRIBUTING.md with .gitignore rules
test: add unit tests for cli_adapter.sh
refactor: simplify inbox_write.sh message handling
```

### PR Description Template

```markdown
## Summary
Brief description of what this PR does.

## Motivation
Why is this change needed? What problem does it solve?

## Changes
- Bullet list of key changes
- Include file paths for context

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manually tested (describe how)

## Screenshots (if applicable)
Add screenshots for UI/UX changes.

## Related Issues
Closes #123
```

### Review Process

1. **Automated checks**: GitHub Actions will run tests and linters
2. **Code review**: At least one maintainer review required
3. **Testing**: Reviewers may request additional tests
4. **Documentation**: Ensure changes are documented

---

## Communication

### GitHub Issues

Use GitHub Issues for:
- **Bug reports** — Include reproduction steps, expected vs. actual behavior, environment details
- **Feature requests** — Describe the use case, proposed solution, alternatives considered
- **Questions** — Ask about implementation details, design decisions

**日本語でのイシュー報告も歓迎します** (Issues in Japanese are welcome).

### GitHub Discussions

Use GitHub Discussions for:
- Design proposals
- Architecture questions
- Best practices
- Showcase your workflow

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run '...'
2. See error

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment**
- OS: [e.g., WSL2 Ubuntu 22.04]
- Claude Code version: [e.g., 1.2.3]
- Shell: [e.g., bash 5.1]

**Additional context**
Any other context about the problem.
```

---

## License

By contributing to multi-agent-shogun, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

## Credits

Contributions are recognized in the project README. Thank you for making multi-agent-shogun better!
