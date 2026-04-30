# Template: Proposal Integration (TMPL-INTEG-PROPOSAL)

> **Use when**: Integrating proposals, recommendations, or strategy documents from
> multiple experts/perspectives. Focus on aligning underlying assumptions.

## Pre-Integration Checklist

- [ ] Extract the core assumption behind each proposal
- [ ] Identify where assumptions conflict
- [ ] Resolve assumption conflicts before merging recommendations
- [ ] Check that merged recommendations don't contradict each other

## Assumption Extraction Template

For each input:

```
Report: [filename]
Expert/Perspective: [who]
Core Assumptions:
  1. [Assumption about the current state]
  2. [Assumption about constraints]
  3. [Assumption about goals/priorities]
Recommendations:
  1. [Recommendation] — based on assumption [#]
  2. [Recommendation] — based on assumption [#]
```

## Assumption Alignment Matrix

| Assumption Topic | Expert A | Expert B | Expert C | Aligned? |
|-----------------|----------|----------|----------|----------|
| Current state | ... | ... | ... | YES/NO |
| Constraints | ... | ... | ... | YES/NO |
| Priorities | ... | ... | ... | YES/NO |

## Integration Approach

1. **Align assumptions first** — establish a shared factual baseline
2. **Group complementary recommendations** — proposals that don't conflict
3. **Resolve competing recommendations** — choose based on aligned assumptions
4. **Synthesize** — create unified strategy that incorporates the best of each input

## Output Structure

```markdown
## Assumption Alignment
[Table showing resolved assumptions]

## Integrated Recommendations
### Priority 1: [Recommendation]
- Source: [Expert A + B, aligned on assumption X]
- Rationale: ...

### Priority 2: [Recommendation]
...

## Discarded Recommendations
- [Recommendation from Expert C] — discarded because assumption Y was incorrect
```
