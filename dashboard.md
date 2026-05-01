# Dashboard
Last updated: 2026-04-30 (auto)

> Active tasks only. Historical v1 entries (cmd_001..cmd_080) have been pruned;
> see git history for archaeology.

## Streak

| Item | Value |
|------|-------|
| Streak | 1 day (max: 3) |
| Previous completion | 2026-04-23 (v1 cmd_096/097/099/100) |

## Project Status

- **chrome_extensions**: KindleSnap / BrowseToAnki / PageBreaker / MemeSnap — 4 extensions QC PASS, store submission pending (lord action)
- **claude_side_income**: Video template v4 done (ep001_v4.mp4); YouTube channel + blog domain pending
- **web_update_alert**: Migrated to Prisma 7 + Next 15, local OK, prod deploy pending
- **ai_accelerate_plan**: Presentation deck complete
- **agent-orchestra v2**: in-flight (this repo)

## In Progress

### v2 migration (rebrand + restructure)

Three parallel work streams (cwd: this repo):

1. `instructions/` rebrand: Sengoku role names → functional English (other agent)
2. `scripts/` rebrand: shell helpers updated for new role names (other agent)
3. **this stream**: top-level cleanup (`dashboard.md`, `start_session.sh`, `config/`, `queue/`, `CLAUDE.md`, .gitignore)

After all three streams complete, the orchestrator will commit + open a PR.

## Recently Completed

- **v2-spec**: 34 task spec tree under `specs/` documenting the migration (commits abf2d83 / d4ea3c3)
- **v2 bootstrap**: planner / reviewer / engineer subagent files seeded (a505ada)
- **MIT LICENSE + bilingual README skeleton** (d404210)

## Pending Lord Decisions

### Chrome extensions store rollout

- Chrome Web Store developer account ($5)
- Contact email for privacy-policy.md (5 extensions)
- Create makotonos GitHub repos: kindle-snap, browse-to-anki, page-breaker, meme-snap, catstroll
- For each extension: privacy policy email, git remote + push, 3 store screenshots (1280x800 PNG), Chrome Web Store submission

Estimated total: ~1.5 hours.

### Other follow-ups (deferred from v1)

- multi-agent-shogun push 403 (yohey-w repo permissions)
- video-template branch on `web_update_alert/first` — needs main merge
- YouTube channel "Today's AI Development" (not yet opened)
- Blog domain (~JPY 1,500/year)
- Hugo environment verification
- AI-generated content disclosure policy

## Next Action Candidates

- Finish v2 migration (this work)
- Submit 5 Chrome extensions to the Web Store
- BrowseToAnki contact email
- YouTube / blog launch

---

_Generated as part of the agent-orchestra v2 migration. v1 cmd_001..cmd_080
history removed; consult git log for full provenance._
