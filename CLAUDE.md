# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

A local-first Rails app that ingests, indexes, and browses your historic Claude conversations (both Claude Code sessions and Claude Desktop exports) so they can be searched, labeled, and resumed. It is meant to be run on `localhost:3000` against the user's own `~/.claude/` directory.

## Common commands

- `bin/dev` — runs the dev server via Foreman (`web: bin/rails server`, `css: bin/rails tailwindcss:watch`). Use this rather than `bin/rails s` so Tailwind rebuilds.
- `bin/setup` — install gems, prep DB, etc. (standard Rails setup script).
- `bin/rails db:prepare` — create/migrate DBs. Schema is dumped to `db/structure.sql` (not `schema.rb`) because of FTS5 (see Architecture).
- `bin/rails test` — run unit/controller/integration tests.
- `bin/rails test:system` — run Capybara/Selenium system tests.
- `bin/rails test test/models/conversation_test.rb` — run a single file. Append `:LINE` to run a single test.
- `bin/rubocop` — lint (Rails Omakase).
- `bin/brakeman --no-pager` and `bin/bundler-audit` — security scans.
- `bin/ci` — runs the full CI pipeline locally (driven by `config/ci.rb`); mirrors `.github/workflows/ci.yml` (brakeman, bundler-audit, importmap audit, rubocop, test, system test).
- `bin/rails history:sync` — same import that `POST /sync` triggers from the UI; pulls new/changed JSONL files from `~/.claude/projects`.

## Architecture

### Rails 8 + SQLite + Solid stack
Rails 8.1 on Ruby (see `.ruby-version`). SQLite is used for primary data plus the Solid adapters for cache/queue/cable — production uses four separate SQLite files under `storage/` (see `config/database.yml`). Frontend is Hotwire (Turbo + Stimulus) over importmap, styled with `tailwindcss-rails` and `shadcn-ui`.

### Two import paths feed one data model
The app has **two ingestion sources**, both writing into the same `projects → conversations → messages` schema, distinguished by `conversations.source` (`"code"` or `"desktop"`):

1. **Claude Code** (`app/lib/claude_history/`) — `ClaudeHistory::Importer` walks `~/.claude/projects/*/<session_id>.jsonl`, parsing each line as a record. It dedups on `session_id`, skips files whose `file_mtime` hasn't advanced, derives project from the record's `cwd` via `Project.find_or_create_for_cwd`, and replaces all messages on update (`messages.delete_all` + `Message.insert_all`). Triggered by `POST /sync` (`SyncController`) or the `history:sync` rake task. `RecordParser` normalizes the JSONL record shapes into `role` / `text_content`.
2. **Claude Desktop** (`app/lib/claude_desktop_export/`) — `ClaudeDesktopExport::Importer` reads a user-uploaded `claude.ai` data-export ZIP attached via Active Storage to a `DesktopImport` row. All desktop conversations live under a single synthetic project (`path: "claude-desktop-export"`). Dedup is on the export's conversation `uuid` (stored as `session_id`), updating only when `updated_at` is newer.

Soft-deleted conversations are **never** re-imported — both importers check `Conversation.with_deleted` and skip if `deleted_at` is set. This means deleting in the UI is sticky across resyncs, which is a core product promise.

### Soft delete with default scope
`Conversation` and `Project` both use `deleted_at` + `default_scope { where(deleted_at: nil) }`. To bypass, use the `with_deleted` / `deleted` scopes. The `/trash` page (`TrashController`) and `restore` member routes rely on this. When writing new queries that need to see deleted rows (e.g. importer dedup), remember to unscope.

### FTS5 full-text search
Messages are indexed in a SQLite FTS5 virtual table `messages_fts` with `porter unicode61` tokenization, kept in sync via AFTER INSERT/UPDATE/DELETE triggers (see `db/structure.sql` and the `create_messages_fts` migration). Search (`SearchesController`) queries against this table.

There is a Rails footgun here that `lib/tasks/db_structure_fts.rake` works around: `db:schema:dump` emits the FTS5 shadow tables (`messages_fts_data`, `_idx`, `_docsize`, `_config`) into `structure.sql`, but those names are reserved by SQLite and `db:schema:load` then fails. The rake task hooks `db:schema:dump` to strip those lines after dump. **Do not remove this hook**, and if you add another FTS5 virtual table, the regex there will already cover its shadow tables.

### Models & relationships
`Project` 1—N `Conversation` 1—N `Message`. `Conversation` N—N `Label` through `ConversationLabel`. `Conversation#resume_command` builds the `cd … && claude --resume <session_id>` shell snippet shown in the UI — this is **only** valid for `source: "code"` (returns nil for desktop conversations).

### Counter caches are manual
`Project#refresh_counters!` is called after every import to recompute `conversation_count` and `last_activity_at`. Don't rely on Rails counter_cache for these; the importer manages them explicitly.
