# Template: Fact Integration (TMPL-INTEG-FACT)

> **Use when**: Integrating reports that contain factual claims about real-world entities,
> people, systems, or events. Highest contradiction risk.

## Pre-Integration Checklist

- [ ] Extract ALL factual claims from each input report
- [ ] Create a fact comparison table (Input A vs Input B vs ...)
- [ ] Flag any mismatches (especially "exists" vs "doesn't exist")
- [ ] Consult primary sources for each flagged mismatch
- [ ] Resolve each contradiction with source citation

## Fact Extraction Template

For each input report, list:

```
Report: [filename]
Facts:
  1. [Entity] — [Claim] — [Source line/section]
  2. [Entity] — [Claim] — [Source line/section]
  ...
```

## Cross-Reference Matrix

| Entity/Topic | Report A | Report B | Report C | Conflict? | Resolution |
|-------------|----------|----------|----------|-----------|------------|
| ... | ... | ... | ... | YES/NO | ... |

## Contradiction Resolution Section (Required in Output)

```markdown
## Contradiction Resolution

### [Topic]: [Report A claim] vs [Report B claim]
- **Primary source check**: [what was found]
- **Adopted position**: [which is correct and why]
- **Impact on recommendations**: [how this changes the integrated output]
```

## Critic Review (Recommended for Fact Integration)

If available, request a second agent to review the integrated output specifically for:
- Undetected contradictions
- Logical inconsistencies in the merged narrative
- Facts cited without source verification
