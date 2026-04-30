# shogun-web-research skill update

- Updated source: `/home/tono/.claude/skills/shogun-web-research/SKILL.md`
- Task: `subtask_208a` (`cmd_208`)
- Timestamp: `2026-03-29T11:30:00+09:00`

## Added fact-check protocol

1. Require at least two searches per topic:
   - general web search
   - official-source search such as `site:openai.com changelog` or `site:anthropic.com release notes`
2. Extract publication/update dates from each source and do freshness checks:
   - do not describe information older than 7 days as "latest" or "recent"
   - if no date is available, label it as `日付不明`
3. Cross-check version numbers, model names, and release names against official changelog/release-notes sources:
   - if verified, treat as `公式確認済み`
   - if not verified, mark as `未確認` or `要確認`
4. Do not state unverified claims as facts:
   - append `（未確認）` or remove the claim entirely

## Note

`/home/tono/.claude` is not a Git repository in this environment, so this report records the externally applied skill update in the tracked `multi-agent-shogun` repository.
