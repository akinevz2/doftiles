---
name: himalaya
description: Drive the himalaya email CLI from the agent — list/read/search/send mail non-interactively with --json output. Use when the user asks about email, mailboxes, messages, attachments, or wants you to check or send mail.
---

# Himalaya (email CLI)

`himalaya` is a TOML-configured email CLI at `~/.local/bin/himalaya`
(deployed by the dots `himalaya` stow package). It is fully
scriptable — prefer it over any interactive TUI.

## Configuration

- Public config: `~/.config/himalaya/config.toml` (tracked in the dots
  repo) — three accounts: `akinevz-gmail` (default), `kirilos-gmail`,
  `akinevz-outlook`. Every account authenticates through **oama**
  (OAuth credential manager, the dots `oama` package): its
  `access <email>` command prints a fresh access token; oama renews
  automatically.
- Secrets: OAuth tokens live GPG-encrypted in
  `~/.local/state/oama/<email>.oama`. NEVER read, print, or quote
  these files or any `oama access` output; NEVER send token material
  to any model or log. Token plumbing is the config's job.
- If a call fails with an auth error, run `oama renew <email>`
  (or ask the user to re-run `oama authorize <service> <email>`);
  don't try to extract secrets yourself.

## Core workflow (JSON-first)

Always pass `--json` (or `-o json`) when the output is for parsing —
the table output is for humans.

```sh
himalaya mailbox list --json                 # mailboxes
himalaya envelope list -m INBOX --json       # page of envelopes (page-size from config)
himalaya envelope list -m INBOX -s "subject:foo" --json   # search
himalaya envelope search -m INBOX --json     # server-side search where supported
himalaya message read <id> -m INBOX --json   # full message
himalaya message read <id> -m INBOX          # readable text rendering
himalaya attachment list <id> -m INBOX --json
himalaya flag add seen <ids> -m INBOX        # mark read; `flag` manages flags
himalaya message move <ids> <mailbox> -m INBOX
```

Sending (composes in $EDITOR by default — for the agent prefer flags
or a template file):

```sh
himalaya message send --to a@example.org --subject "..." --body "..."
himalaya message send --template <file>      # full MIME or simple template
```

## Guardrails

- Deleting (`message delete`, mailbox purge) and sending are
  destructive/side-effecting: confirm intent with the user first.
- Never include credential values in command output or reports.
- If a command fails with an auth error, the likely cause is an empty
  KEY in `credentials.env` — tell the user to fill it, don't try to
  extract secrets yourself.
