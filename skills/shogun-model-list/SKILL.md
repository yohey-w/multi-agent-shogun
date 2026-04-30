---
name: shogun-model-list
description: >
  All AI CLI tools × available models × required subscriptions × Bloom max capability.
  Reference table for choosing which models to use in multi-agent-shogun.
  Trigger: "model list", "what models", "model comparison", "which models can I use",
  "モデル一覧", "モデル比較", "どのモデルが使える"
---

# /shogun-model-list — Model Capability Reference

## Overview

Displays a complete reference table of all AI CLI tools, models, required subscriptions,
and maximum Bloom cognitive level per model. Use this before configuring `capability_tiers`
in `config/settings.yaml`.

## When to Use

- "What models can I use with my subscription?"
- "Which model handles L5 tasks?"
- "Compare Claude vs Codex model tiers"
- "Show me all models" / "モデル一覧"
- Before running `/shogun-bloom-config` to understand the landscape

## Instructions

Output the reference tables below directly to the user. No tool calls required.

---

## Bloom's Taxonomy — Quick Reference

| Level | Category | Task Examples |
|-------|----------|---------------|
| L1 | Remember | File copy, template apply, data format |
| L2 | Understand | Summarize, explain, translate |
| L3 | Apply | Implement known patterns, generate boilerplate |
| L4 | Analyze | Debug, code review, root cause analysis |
| L5 | Evaluate | Architecture review, design trade-off judgment |
| L6 | Create | Novel architecture, requirements design, strategy |

---

## Claude Code (Anthropic)

### Subscription Plans

| Plan | Monthly | Opus 4.6 | Sonnet 4.6 | Haiku 4.5 | Extended Thinking |
|------|---------|----------|------------|-----------|-------------------|
| Free | $0 | ✗ | ✓ | ✓ | ✗ |
| Pro | $20 | ✓ | ✓ | ✓ | ✓ |
| Max 5x | $100 | ✓ | ✓ | ✓ | ✓ |
| Max 20x | $200 | ✓ | ✓ | ✓ | ✓ |

> Pro/Max 5x/Max 20x have the same model access. The difference is usage quota (5x/20x = multiplier of Pro).

### Claude Models × Bloom Capability

| Model | Bloom Max | Best For | Notes |
|-------|-----------|----------|-------|
| `claude-haiku-4-5-20251001` | **L3** | High-volume L1-L3 tasks, fast responses | $1/$5/M; SWE-bench 73.3% (4pp below Sonnet 4.5); extended thinking available |
| `claude-sonnet-4-6` | **L5** | Code review, analysis, orchestration | Best balance — $3/$15/M; SWE-bench 79.6%, 1M context |
| `claude-opus-4-6` | **L6** | Novel design, strategy, architecture | $5/$25/M; SWE-bench 80.8% (only 1.2pp above Sonnet 4.6); use for true L6 only |

> **Extended Thinking** (available Pro+): Adds ~1 Bloom level of effective capability on complex reasoning tasks.

### Fixed Agent Assignments (Recommended)

| Agent | Recommended Model | Bloom Use | Reason |
|-------|------------------|-----------|--------|
| Shogun (You) | `claude-opus-4-6` | L6 | Strategic decisions, final review |
| Karo (Manager) | `claude-sonnet-4-6` | L4-L5 | Task orchestration; Opus is overkill here |
| Gunshi (Strategist) | `claude-opus-4-6` | L5-L6 | Deep QC, architecture evaluation |
| Ashigaru 1–7 | Configured via `capability_tiers` | L1-L3 | Workers — routed by Bloom level |

---

## OpenAI Codex CLI

### Subscription Plans

| Plan | Monthly | Spark | gpt-5.3-codex | codex-mini | codex-max |
|------|---------|-------|---------------|------------|-----------|
| Free / Go ($8) | $0–$8 | ✗ | ✗ (limited) | ✗ | ✗ |
| Plus | $20 | ✗ (**Pro only**) | ✓ | ✓ | ✓ |
| Pro | $200 | ✓ | ✓ | ✓ | ✓ |

> **gpt-5.3-codex-spark requires ChatGPT Pro ($200).** ChatGPT Plus ($20) does NOT include Spark.

### Codex Models × Bloom Capability

| Model | Bloom Max | Best For | Notes |
|-------|-----------|----------|-------|
| `gpt-5.3-codex-spark` | **L3** | High-volume L1-L3 tasks at 1000+ tok/sec | Separate quota from gpt-5.3-codex; blazing fast |
| `gpt-5-codex-mini` | **L2** | Minimal quota usage for trivial tasks | Lightweight alternative to Spark |
| `gpt-5.3-codex` | **L4** | Analysis, debugging, code review | Standard workhorse |
| `gpt-5.1-codex-max` | **L5** | Complex analysis, design evaluation | Highest Codex capability |

> **L6 gap**: No Codex model reliably handles novel creative design (L6). For L6 tasks, Claude Opus is recommended.

---

## Capability Summary (All Models, Cross-CLI)

| Model | CLI | Bloom Max | Min Subscription | Notes |
|-------|-----|-----------|-----------------|-------|
| `gpt-5-codex-mini` | Codex CLI | L2 | ChatGPT Plus | Lightweight, minimal quota |
| `claude-haiku-4-5-20251001` | Claude Code | **L3** | Claude Free | Best Claude cost-efficiency; SWE-bench 73.3% |
| `gpt-5.3-codex-spark` | Codex CLI | L3 | **ChatGPT Pro** | 1000+ tok/s; Terminal-Bench 58.4% |
| `gpt-5.3-codex` | Codex CLI | L4 | ChatGPT Plus | Terminal-Bench 77.3%; 400K+ context |
| `claude-sonnet-4-6` | Claude Code | L5 | Claude Free | $3/$15/M; SWE-bench 79.6%; 1M context; math +27pt vs Sonnet 4.5 |
| `gpt-5.1-codex-max` | Codex CLI | L5 | ChatGPT Plus | Highest Codex capability |
| `claude-opus-4-6` | Claude Code | L6 | Claude Pro | $5/$25/M; SWE-bench 80.8%; reserve for true L6 tasks |

---

## Next Step

To generate a ready-to-paste `capability_tiers` YAML for your subscription:

```
/shogun-bloom-config
```

Or tell the Shogun: "set up capability tiers for my subscription"
