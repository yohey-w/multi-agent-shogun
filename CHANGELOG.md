# Changelog

All notable changes to this project will be documented in this file.

## [4.4.1] - 2026-03-28

### Added
- Android: Raw/UI toggle in ratelimit dialog for debugging SSH output
- Android: SSH key file picker in settings (load private key from device storage)
- Android: parse failure fallback — show raw output when no data parsed
- `ratelimit_check.sh`: zoom-capture for Codex /status blocks (fixes narrow pane truncation)

### Fixed
- Android: ratelimit display not working (stderr not captured, missing 2>&1)
- Android: SSH private key loading (read file bytes instead of path reference)
- `ratelimit_check.sh`: extract latest /status block with awk parser to avoid stale data

### Changed
- SshManager: capture stderr + log for diagnostics
- AgentsViewModel: show executed command in SSH error messages

## [4.4.0] - 2026-03-28

### Added
- karo daily log: cmd完了時に `logs/daily/YYYY-MM-DD.md` へサマリーを自動追記する機能を導入 (PR #95)
- `.gitignore`: `.claude/settings.local.json` を除外対象に追加

### Changed
- `instructions/karo.md`: ntfy通知ステップを6→7に移動、daily log appendをステップ6に挿入
- `instructions/roles/karo_role.md`: 同期済み
- 全CLI向け generated instructions を再生成（codex/copilot/kimi-karo.md）

## [4.3.0] - 2026-03-28

### Added
- `shutsujin_departure.sh`: all Claude Code agents now launch with `--effort max` by default (shogun, karo, ashigaru, gunshi)

## [4.2.0] - 2026-03-24

### Added
- `install.bat`: dynamically resolve WSL `$HOME` via `wsl -e bash -c "echo $HOME"` so instructions work on any username/PC
- `shutsujin_departure.sh`: `csst` alias now uses `$HOME/multi-agent-shogun` instead of hardcoded path

### Changed
- `install.bat`: repository reference updated from `feature-shogun` to `multi-agent-shogun`
- `config/settings.yaml`: `skills/logs/images` paths changed to relative `./` paths for portability
- `scripts/backup_daily.sh`: cron example uses `$HOME`-based path
- Regenerated `AGENTS.md` and `copilot-instructions.md` (bloom_routing_rule + Post-Compaction Recovery section)

### Fixed
- `inbox_write.sh`: removed `xxd` dependency (CI compatibility)
- `tests/unit/test_idle_flag.bats`: updated T-008 to match v4.0.1 idle flag design (preserve not delete)
