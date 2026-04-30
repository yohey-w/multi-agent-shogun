# Philosophy

> "Don't execute tasks mindlessly. Always keep 'fastest × best output' in mind."

## Five Core Principles

### 1. Autonomous Formation Design

Design task formations based on complexity, not templates. A simple file rename doesn't need 8 Ashigaru. A complex refactor across 20 files does. The Karo analyzes each command and decides the optimal formation — sometimes 1 Ashigaru, sometimes all 8 in parallel with dependency chains.

### 2. Parallelization

Use subagents to prevent single-point bottlenecks. The Karo decomposes tasks into independent subtasks and assigns them to multiple Ashigaru simultaneously. Dependent tasks use `blocks`/`blockedBy` in YAML to ensure correct execution order while maximizing parallel throughput.

### 3. Research First

Search for evidence before making decisions. Agents don't rely solely on their training data — they actively research using web search, file exploration, and codebase analysis before proposing solutions. This is especially critical for tasks involving external APIs, libraries, or current best practices.

### 4. Continuous Learning

Don't rely solely on model knowledge cutoffs. The system uses Memory MCP to persist lessons learned, discovered patterns, and operational insights across sessions. When an agent encounters a problem it has solved before, it checks memory first. When it learns something new, it records it for future reference.

### 5. Triangulation

Multi-perspective research with integrated authorization. Important decisions are validated from multiple sources — not just one search result or one file. The system cross-references documentation, existing code patterns, and web resources before committing to an approach.

## Design Decisions

### Why a hierarchy (Shogun → Karo → Ashigaru)?

1. **Instant response**: The Shogun delegates immediately, returning control to you
2. **Parallel execution**: The Karo distributes to multiple Ashigaru simultaneously
3. **Single responsibility**: Each role is clearly separated — no confusion
4. **Scalability**: Adding more Ashigaru doesn't break the structure
5. **Fault isolation**: One Ashigaru failing doesn't affect the others
6. **Unified reporting**: Only the Shogun communicates with you, keeping information organized

### Why Mailbox System?

1. **State persistence**: YAML files provide structured communication that survives agent restarts
2. **No polling needed**: `inotifywait` is event-driven (kernel-level), reducing API costs to zero during idle
3. **No interruptions**: Prevents agents from interrupting each other or your input
4. **Easy debugging**: Humans can read inbox YAML files directly to understand message flow
5. **No conflicts**: `flock` (exclusive lock) prevents concurrent writes — multiple agents can send simultaneously without race conditions
6. **Guaranteed delivery**: File write succeeded = message will be delivered. No delivery verification needed, no false negatives
7. **Nudge-only delivery**: `send-keys` transmits only a short wake-up signal (timeout 5s), not full message content. Agents read from their inbox files themselves

### Why only the Karo updates dashboard.md

1. **Single writer**: Prevents conflicts by limiting updates to one agent
2. **Information aggregation**: The Karo receives all Ashigaru reports, so it has the full picture
3. **Consistency**: All updates pass through a single quality gate
4. **No interruptions**: If the Shogun updated it, it could interrupt the Lord's input

### Why Skills are not committed to the repo

Skills in `.claude/commands/` are excluded from version control by design:
- Every user's workflow is different
- Rather than imposing generic skills, each user grows their own skill set
- Skills emerge organically during operation — you approve candidates as they're discovered
