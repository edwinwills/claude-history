# Claude History

<img width="1672" height="1234" alt="Claude History: projects and conversations list" src="https://github.com/user-attachments/assets/d31bfc73-f4b2-45e8-ba7d-2a8aab634c72" />

A local-first Rails app for browsing, searching, labelling and resuming your past Claude conversations. It reads Claude Code sessions straight from `~/.claude/projects` and imports Claude Desktop / claude.ai conversations from a data export, so both appear side by side in one interface.

It runs on `localhost` against your own files. Nothing is sent anywhere.

## Features

### Two sources, one history
- **Claude Code sessions.** Press **Sync** in the header, or run `bin/rails history:sync`, to import every `~/.claude/projects/*/<session>.jsonl` file. Re-syncing is incremental: a file is re-read only when its modification time changes.
- **Claude Desktop / claude.ai conversations.** Upload a data export on the **Import** page. Conversations are deduplicated by their UUID and updated only when the export has a newer version.
  - **Option A:** upload the official export ZIP (claude.ai → Settings → Data controls → Export data).
  - **Option B:** for Team/Enterprise accounts where the export button is hidden, drag the included bookmarklet to your bookmarks bar. It runs in your logged-in claude.ai tab, pages through all your conversations across organisations (skipping ones you can't list) and downloads a `claude-export.json` you can upload.
- Every conversation shows a **Code** or **Desktop** badge, and the home page can be filtered by source.

### Browsing
- **Projects** are derived from each session's working directory and sorted by latest activity. All Desktop conversations sit under one "claude-desktop-export" project.
- The home page has **Projects** and **Conversations** tabs, with filters for source and label.
- The **conversation view** shows the full transcript:
  - Messages render as Markdown.
  - Tool calls, tool results and thinking blocks are collapsible.
  - claude.ai's "not supported" placeholders are replaced with a clear notice.
  - Each conversation shows its git branch, start time, message count and session ID.
- **Subagents:** transcripts written by Claude Code subagents (`<session>/subagents/agent-*.jsonl`) are imported with their parent session. They're listed on the conversation page, and each Agent tool call links to the subagent's own transcript.

### Search
- Full-text search across every message, backed by SQLite FTS5 (Porter stemming, Unicode tokenisation).
- Results are grouped by conversation, show project and recency, and return up to 100 matches. Conversations in the trash are excluded.

### Organising
- **Rename** a conversation inline. Clearing the custom title falls back to the derived one.
- **Labels:** colour-coded labels with a colour picker, managed on the **Labels** page. You can add several to a conversation and filter the home page by any of them.
- **Trash:** delete a conversation, or a whole project together with its conversations, without touching the files in `~/.claude`. Deletion is sticky: re-syncing or re-importing never brings a trashed conversation back. Restore anything from the **Trash** page.

### Resuming
- Each Claude Code conversation has a one-click **Copy** for `cd <project> && claude --resume <session-id>`, so you can pick it up in a terminal.
- Desktop conversations link back to the original on claude.ai.

### Usage stats
The **Stats** page reports Claude Code activity by day, week or month, with the change from the previous period:
- **Totals:** total and output tokens, API calls, sessions, cache hit rate, prompts sent, active projects and average output per call.
- **Tokens over time:** a stacked chart, hourly for a day and daily otherwise.
- **Models:** token usage broken down by model.
- **Subagents:** spawns, background share, the share of sessions that delegate, the subagent share of tokens, a breakdown by agent type and the sessions that delegate most.
- **Top lists:** projects, tools and heaviest conversations.

Token counts come from each response's `usage` and are counted once per API response, so totals aren't inflated.

### Interface
- Light, dark and system themes.
- Built with Hotwire (Turbo + Stimulus), Tailwind CSS v4 and shadcn-ui components.

## Requirements
- Ruby (the version in `.ruby-version`; [mise](https://mise.jdx.dev) or any Ruby version manager will read it)
- Node.js / npm (for the Tailwind build)
- SQLite 3
- Claude Code sessions in `~/.claude/projects`, a claude.ai export, or both

## Installation

```sh
git clone https://github.com/edwinwills/claude-history.git
cd claude-history
mise install          # installs the Ruby version from .ruby-version
npm install           # JS packages used by the Tailwind build
bin/setup             # installs gems and prepares the database
bin/dev               # starts Rails plus the Tailwind watcher
```

Then open <http://localhost:3000> and press **Sync** to import your Claude Code sessions.

`bin/setup` starts the server when it finishes. Use `bin/setup --skip-server` to only install. Use `bin/dev` rather than `bin/rails s` so Tailwind rebuilds as you go.

## Usage

| Task | How |
| --- | --- |
| Import or refresh Claude Code sessions | **Sync** button, or `bin/rails history:sync` |
| Import Claude Desktop conversations | **Import** page: upload the export ZIP or the bookmarklet's JSON |
| Search | Search box in the header, or `/search?q=…` |
| Resume a session | Open the conversation and copy the resume command |
| Recover something deleted | **Trash** page → Restore |
| See usage | **Stats** page |

## Development

```sh
bin/rails test           # unit, controller and integration tests
bin/rails test:system    # system tests (Capybara + Selenium)
bin/rubocop              # lint (Rails Omakase)
bin/brakeman --no-pager  # static security scan
bin/bundler-audit        # gem vulnerability audit
bin/ci                   # full CI pipeline locally (mirrors .github/workflows/ci.yml)
```

The schema is stored in `db/structure.sql` rather than `schema.rb` because of the FTS5 virtual table. See [CLAUDE.md](CLAUDE.md) for the architecture, the import pipeline and the SQLite gotchas to avoid.

See [CHANGELOG.md](CHANGELOG.md) for the version history.

## License

[MIT](LICENSE)
