# INTEG-001: Integration Task Contradiction Detection

> **Applies to**: All integration tasks where 2+ input reports are merged into one output.
> **Origin**: cmd_011 post-mortem (fact contradiction was missed during integration).

## Core Principle

When integrating multiple input reports, the integrating agent **MUST** detect and resolve contradictions between inputs **before** merging content. Contradictions left unresolved propagate as errors into the final deliverable.

## Mandatory Pre-Integration Steps

### Step 1: Fact Reconciliation

Extract all factual claims from each input report and cross-reference:

| Input A Claim | Input B Claim | Match? | Resolution |
|---------------|---------------|--------|------------|
| "Client has 8h of video content" | "Client should start creating videos" | CONFLICT | Check primary source |

**High-risk contradiction types:**
- "Already doing X" vs "Should start X" (existence vs non-existence)
- Numeric/timeline inconsistencies
- Contradictory descriptions of the same entity/person/system
- Conflicting technical assumptions or prerequisites

### Step 2: Resolve Contradictions

When a contradiction is found:

1. **Consult primary sources** — transcripts, raw data, meeting notes referenced in task YAML
2. **Adopt the factually correct version** and modify proposals based on incorrect assumptions
3. **Document the resolution** in a "Contradiction Resolution" section of the output

### Step 3: Escalate Only If Unresolvable

If primary sources cannot resolve the contradiction → report to karo with details.
Karo escalates to shogun → lord if needed.

## Karo's Responsibility

When assigning integration tasks, the task YAML **MUST** include:

```yaml
description: |
  ■ INTEG-001 (Mandatory)
  Detect and resolve contradictions between input reports before integration.
  Pay special attention to "already doing" vs "should start" assumption mismatches.

  ■ Primary Sources (for fact-checking)
  - /path/to/transcript.md
  - /path/to/original_data.yaml

  ■ Input Reports
  - /path/to/report1.md
  - /path/to/report2.md
```

## Integration Type Selection

Choose the appropriate template based on integration type:

| Integration Type | Template | Contradiction Check Depth |
|-----------------|----------|--------------------------|
| Fact integration | `templates/integ_fact.md` | Highest — line-by-line fact matching |
| Proposal integration | `templates/integ_proposal.md` | High — assumption alignment |
| Code integration | `templates/integ_code.md` | Medium — CI/test-driven |
| Analysis integration | `templates/integ_analysis.md` | High — framework alignment |

Karo determines the type and includes the appropriate template reference in the task YAML.
