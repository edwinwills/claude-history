# Changelog

All notable changes to Claude History are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

The project had no tagged releases before this file was written. The versions below were reconstructed from the git history: each groups the pull requests merged up to its date. Pull request numbers refer to [edwinwills/claude-history](https://github.com/edwinwills/claude-history/pulls).

## Unreleased

### Changed
- Dependency updates: bootsnap 1.26.1 (#53), kamal 2.12.0 (#38), solid_queue 1.7.2 (#55), selenium-webdriver 4.52.0 (#54), thruster 0.1.27 (#52), solid_cable 4.1.0 (#51).

## 0.4.0 - 2026-11-09

### Added
- **Stats page** (`/stats`) for Claude Code usage by day, week or month, with period-over-period change:
  - Tiles for total and output tokens, API calls, sessions, cache hit rate, prompts sent, active projects and average output per call.
  - A stacked tokens-over-time chart.
  - A per-model breakdown.
  - Top projects, top tools and heaviest conversations. (#50)
- Model and token usage (input, output, cache write, cache read) are extracted from assistant records into message columns and backfilled for existing data. Usage is kept once per API response so sums aren't inflated. (#50)
- **Subagent transcripts:** `<session>/subagents/agent-*.jsonl` files and their `.meta.json` are imported into a new `subagents` table and linked to the parent conversation. (#50)
  - Conversation pages list their subagents and link Agent tool calls to the subagent transcript.
  - The stats page gains a Subagents section: spawns, background share, sessions delegating, subagent token share, breakdown by agent type and most delegating sessions.

### Changed
- Migrated to Tailwind CSS v4 (tailwindcss-rails 4.x). (#37)
- CI runners pinned to `ubuntu-24.04`. (#37)
- Dependency updates: Rails 8.1.3.1 (#49), solid_queue 1.6.0 (#48), solid_cable 4.0.2 (#47), thruster 0.1.23 (#45), selenium-webdriver 4.46.0 (#44), rubyzip 3.4.1 (#42), sqlite3 2.9.5 (#33), Brakeman 8.0.5 (#36) then 8.1.0 (#37); GitHub Actions `actions/setup-node` v7 (#43), `actions/cache` v6 (#40), `actions/checkout` v7 (#34).

### Removed
- Unused `image_processing` gem. (#37)

### Security
- Patched gems flagged by bundler-audit, including Rails 8.1.4.1 (a critical Active Storage advisory), rack 3.2.8, net-ssh 7.3.10, sqlite3 2.10.2, nokogiri 1.19.7, loofah 2.25.3, rails-html-sanitizer 1.7.2, addressable 2.9.2 and crass 1.0.8. (#37)

## 0.3.2 - 2026-06-10

### Changed
- Dependency updates: selenium-webdriver 4.44.0 (#21), thruster 0.1.21 (#22), solid_cable 4.0.0 (#24), jbuilder 2.15.1 (#28), rubyzip 3.3.1 (#29), bootsnap 1.24.6 (#30), image_processing 2.0.2 (#31).
- Removed the `CHECKSUMS` section from `Gemfile.lock`. (#32)

### Security
- Patched nokogiri, puma, erb and net-imap. (#32)

## 0.3.1 - 2026-05-13

### Changed
- Dependency updates: puma 8.0.1 (#14), rubyzip 3.3.0 (#16), bootsnap 1.24.3 (#17), sqlite3 2.9.4 (#18).

## 0.3.0 - 2026-04-28

### Added
- Projects and Conversations tabs on the home page, so all conversations can be browsed across projects. (#13)
- `CLAUDE.md` with commands and an architecture overview for working on the codebase. (#12)

### Fixed
- claude.ai's "not supported" placeholder blocks in Desktop conversations now render as a clear notice. (#8)

### Changed
- Dependency updates: propshaft 1.3.2 (#11), rubyzip 3.2.2 (#10), `actions/setup-node` v6 (#9).

## 0.2.0 - 2026-04-17

### Added
- **Claude Desktop import:** upload the official claude.ai data-export ZIP on the new Import page. Conversations are deduplicated by UUID, updated only when newer, and grouped under a single "claude-desktop-export" project. (#5)
- A browser bookmarklet for Team/Enterprise accounts where the export button is hidden. It fetches your conversations from your logged-in claude.ai tab, paginates across organisations (skipping ones that return 403) and downloads a JSON file the Import page accepts. (#5)
- Code/Desktop source badges everywhere conversations appear, and a source filter on the home page. (#6)
- Soft-delete for whole projects, cascading to their conversations, with restore from the Trash. (#7)

## 0.1.0 - 2026-04-17

### Added
- Import of Claude Code sessions from `~/.claude/projects/*/<session>.jsonl` via the Sync button or `bin/rails history:sync`. The import is incremental (by file modification time), and projects are derived from each session's working directory.
- Project list and conversation view with Markdown rendering and collapsible tool calls, tool results and thinking blocks.
- Full-text search across all messages using SQLite FTS5.
- Copy-to-clipboard `claude --resume` command for every Claude Code conversation.
- Inline renaming of conversations.
- Colour-coded labels with a colour picker, a Labels page and label filtering on the home page.
- Soft-delete with a Trash page and restore. Deleted conversations are never re-imported by later syncs.
- Light, dark and system themes.
- shadcn-ui component styling.
- Test suite for models, services and controllers, and a GitHub Actions CI pipeline (Brakeman, bundler-audit, importmap audit, RuboCop, tests, system tests).

### Fixed
- `db:schema:dump` strips FTS5 shadow tables from `structure.sql` so `db:schema:load` works.
- Clicking a conversation title inside a Turbo frame no longer shows "Content missing".

