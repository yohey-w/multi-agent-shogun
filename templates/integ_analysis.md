# Template: Analysis Integration (TMPL-INTEG-ANALYSIS)

> **Use when**: Integrating analytical reports that use different frameworks,
> methodologies, or data sources to examine the same topic.

## Pre-Integration Checklist

- [ ] Identify the analytical framework used by each input
- [ ] Extract key findings and their supporting evidence
- [ ] Check for contradictory conclusions from different frameworks
- [ ] Reconcile methodology differences before synthesizing

## Framework Comparison Template

| Dimension | Report A | Report B | Report C |
|-----------|----------|----------|----------|
| Framework/Method | ... | ... | ... |
| Data Sources | ... | ... | ... |
| Key Finding 1 | ... | ... | ... |
| Key Finding 2 | ... | ... | ... |
| Conclusion | ... | ... | ... |

## Tension Detection

When different analyses reach different conclusions:

1. **Check if the difference is due to different frameworks** — both may be valid from their perspective
2. **Check if the difference is due to different data** — one may have more complete information
3. **Check if the difference is a genuine disagreement** — requires deeper analysis

## Integration Approach

1. **Map each analysis to a common structure** (findings → evidence → conclusion)
2. **Identify convergent findings** — where analyses agree, confidence is high
3. **Identify divergent findings** — examine why and which is more robust
4. **Synthesize** — create a unified analysis that acknowledges multiple perspectives

## Output Structure

```markdown
## Methodology Comparison
[Framework comparison table]

## Convergent Findings (High Confidence)
- [Finding]: Supported by [Report A, B, C]

## Divergent Findings (Requires Judgment)
- [Topic]: Report A says X, Report B says Y
  - Reason for divergence: [different data / different framework / genuine disagreement]
  - Recommended position: [X / Y / nuanced synthesis]

## Integrated Analysis
[Unified narrative incorporating all perspectives]

## Limitations
[Gaps, assumptions, areas needing further research]
```
