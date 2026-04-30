# Security Policy

## Supported Versions

multi-agent-shogun is currently in active development. Security updates are provided for the latest release on the `main` branch.

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 3.0   | :x:                |

We recommend always using the latest version from the `main` branch.

---

## Security Considerations

### 1. Whitelist-Based .gitignore

This project uses a **whitelist-based .gitignore** strategy to prevent accidental commits of sensitive data:

- Default `*` excludes everything
- Only explicitly allowed files are tracked
- `projects/`, `queue/`, and `memory/` are intentionally excluded

**Always verify what you're committing**:
```bash
git status
git diff --cached
```

### 2. API Keys and Tokens

**NEVER commit API keys, tokens, or credentials to the repository.**

Sensitive data should be stored in:
- Environment variables (e.g., `GITHUB_PERSONAL_ACCESS_TOKEN`)
- `config/settings.yaml` (which is git-ignored for secrets)
- `.env` files (not tracked by git)

**MCP Server Configuration**: When adding MCP servers with credentials:
```bash
# Good: Use environment variables
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token -- npx -y @modelcontextprotocol/server-github

# Bad: Hardcoding tokens
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_1234567890abcdef -- npx -y @modelcontextprotocol/server-github
```

### 3. ntfy Topic Security

Your **ntfy topic name is your password**. Anyone who knows your topic can:
- Read your notifications
- Send commands to your Shogun

**Best practices**:
- Use a hard-to-guess topic name (e.g., `shogun-random-string-12345`, not `shogun` or `my-tasks`)
- Never share your topic in screenshots, blog posts, or GitHub commits
- Keep `config/settings.yaml` (which contains your topic) excluded from git

**Example of a secure topic**:
```yaml
# config/settings.yaml (git-ignored)
ntfy_topic: "your-random-topic-name-here"  # Random, hard to guess
```

### 4. Project Data Privacy

The `projects/` directory is excluded from git by design:
- Contains confidential client information
- Includes contracts, invoices, and business details
- Should NEVER be committed to version control

**If you need to share project structure examples**, create sanitized templates in `templates/` instead.

### 5. Memory MCP Data

The `memory/` directory contains user-specific persistent memory:
- Personal preferences
- Project history
- Learned patterns

This data is **excluded from git** to protect user privacy. Never commit `memory/*.jsonl` files.

### 6. Shell Script Injection

When contributing shell scripts, be aware of injection risks:

**Unsafe**:
```bash
# DO NOT use eval or unquoted variables
eval "$USER_INPUT"  # Injection risk!
echo $VARIABLE      # Word splitting risk!
```

**Safe**:
```bash
# Always quote variables
echo "$VARIABLE"

# Use arrays for commands
cmd=("git" "commit" "-m" "$MESSAGE")
"${cmd[@]}"
```

All scripts must pass `shellcheck` to catch common security issues.

### 7. tmux Session Security

tmux sessions run locally and are accessible to anyone with access to your machine:
- Do not run multi-agent-shogun on shared/untrusted systems
- Be aware that tmux sessions persist after logout (unless explicitly killed)
- Use `tmux kill-session -t shogun` to clean up after use

---

## Reporting a Vulnerability

**We take security vulnerabilities seriously.** If you discover a security issue, please report it responsibly.

### How to Report

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. **Use GitHub Security Advisories** (recommended):
   - Navigate to the [Security tab](https://github.com/yohey-w/multi-agent-shogun/security)
   - Click "Report a vulnerability"
   - Provide detailed information (see below)

3. **Or email the maintainer** (if GitHub Security Advisories is unavailable):
   - Email: See GitHub profile for contact information
   - Subject: `[SECURITY] multi-agent-shogun vulnerability report`

### What to Include

When reporting a vulnerability, please include:

- **Description**: Clear summary of the vulnerability
- **Impact**: What could an attacker do with this vulnerability?
- **Steps to Reproduce**: Detailed steps to reproduce the issue
- **Environment**: OS, shell version, Claude Code version, etc.
- **Proof of Concept**: Code or screenshots demonstrating the issue (if applicable)
- **Suggested Fix**: If you have ideas for how to fix it (optional)

**Example Report**:
```
Title: Shell injection in inbox_write.sh via unsanitized message content

Description:
The inbox_write.sh script does not sanitize user input before writing
to YAML files, allowing command injection through crafted messages.

Impact:
An attacker could send a malicious message via ntfy that executes
arbitrary commands on the host system.

Steps to Reproduce:
1. Send the following ntfy message: `$(rm -rf /)`
2. inbox_listener.sh receives and writes to ntfy_inbox.yaml
3. Shogun reads the YAML file and executes the embedded command

Environment:
- OS: WSL2 Ubuntu 22.04
- Claude Code: 1.2.3
- Bash: 5.1.16

Proof of Concept:
[Attach screenshot or code snippet]

Suggested Fix:
Sanitize input by escaping special characters before writing to YAML,
or use a proper YAML library instead of raw string concatenation.
```

---

## Response Timeline

We aim to respond to security reports within:

- **Initial response**: 48 hours
- **Triage and assessment**: 1 week
- **Fix development**: Depends on severity
  - Critical: 1-2 weeks
  - High: 2-4 weeks
  - Medium: 4-8 weeks
  - Low: Best effort

**Note**: These are target timelines. Actual response may vary based on maintainer availability and issue complexity.

### Severity Levels

| Severity | Description | Example |
|----------|-------------|---------|
| **Critical** | Remote code execution, data breach | Shell injection via ntfy messages |
| **High** | Privilege escalation, credential exposure | API keys leaked in logs |
| **Medium** | Information disclosure, DoS | Sensitive data in error messages |
| **Low** | Minor information leak | Version disclosure |

---

## Security Updates

Security fixes will be:
1. Developed in a private branch
2. Tested thoroughly
3. Released with a security advisory
4. Announced in the project README and GitHub Releases

**Critical vulnerabilities** may result in an emergency release outside the normal release cycle.

---

## Scope

### In Scope

The following are considered in scope for security reports:

- **Shell scripts** in `scripts/`, `lib/`, and root directory
- **YAML parsing** and file handling in queue system
- **ntfy integration** (message handling, authentication)
- **tmux integration** (command injection, session hijacking)
- **MCP server configuration** (credential exposure)
- **File permissions** and access control issues
- **Dependency vulnerabilities** in npm packages used by MCP servers

### Out of Scope

The following are NOT considered security vulnerabilities:

- **Features working as designed**: For example, ntfy topic name being "public" is a documented limitation, not a vulnerability
- **Third-party services**: Issues in ntfy.sh, Claude Code CLI, or MCP servers themselves (report those upstream)
- **Local access**: An attacker with local shell access can already do anything
- **Denial of Service via resource exhaustion**: For example, spawning 1000 agents to consume memory
- **Social engineering**: Tricking users into running malicious commands
- **Issues requiring physical access** to the machine

---

## Security Best Practices for Users

To keep your multi-agent-shogun installation secure:

1. **Keep dependencies updated**:
   ```bash
   # Update Claude Code CLI
   curl -fsSL https://claude.ai/install.sh | bash

   # Update MCP servers
   claude mcp list
   # Re-run install commands for outdated servers
   ```

2. **Use strong ntfy topics**:
   ```bash
   # Generate a random topic
   echo "shogun-$(openssl rand -hex 8)"
   ```

3. **Review scripts before running**:
   ```bash
   # Always check what a script does before running it
   cat shutsujin_departure.sh
   ```

4. **Limit tmux session access**:
   ```bash
   # Set restrictive file permissions
   chmod 700 ~/.tmux.conf
   ```

5. **Monitor logs for suspicious activity**:
   ```bash
   # Check logs directory
   ls -lah logs/
   ```

6. **Verify .gitignore before committing**:
   ```bash
   # Always check what you're about to commit
   git status
   git diff --cached
   ```

---

## Acknowledgments

We appreciate the security research community's efforts to keep open-source software secure. Security researchers who responsibly disclose vulnerabilities will be acknowledged in:

- The security advisory
- The project README (if desired)
- GitHub Security Advisories hall of fame

---

## Contact

For security-related questions (not vulnerability reports):
- Open a [GitHub Discussion](https://github.com/yohey-w/multi-agent-shogun/discussions)
- Tag your question with `security` label

For vulnerability reports, use the process described in [Reporting a Vulnerability](#reporting-a-vulnerability).

---

**Thank you for helping keep multi-agent-shogun secure!**
