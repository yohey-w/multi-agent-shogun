# Template: Code Integration (TMPL-INTEG-CODE)

> **Use when**: Integrating code changes from multiple agents working on different
> parts of the same codebase. Contradiction detection is primarily test-driven.

## Pre-Integration Checklist

- [ ] Review all modified files for overlap (same file touched by multiple agents)
- [ ] Check for conflicting imports, type definitions, or API signatures
- [ ] Run existing tests to establish baseline
- [ ] Merge changes and resolve any git conflicts
- [ ] Run full test suite after merge
- [ ] Check for runtime conflicts (same resource, port, config key, etc.)

## Conflict Detection Approach

Code integration relies on **automated tooling** rather than manual fact-checking:

| Check | Tool | When |
|-------|------|------|
| File overlap | `git diff --name-only` comparison | Before merge |
| Type/API conflicts | TypeScript/linter | After merge |
| Logic conflicts | Test suite | After merge |
| Runtime conflicts | Manual review of config/env | After merge |

## Integration Steps

1. **List all files modified** by each agent
2. **Identify overlapping files** — these need manual review
3. **Merge non-overlapping changes** first
4. **Resolve overlapping files** — understand intent of each change
5. **Run tests** — fix any failures
6. **Verify integration** — does the combined result meet the original cmd objective?

## Output

The integrated codebase itself is the deliverable. Report should include:
- Files merged
- Conflicts resolved (if any)
- Test results
- Any remaining issues or TODOs
