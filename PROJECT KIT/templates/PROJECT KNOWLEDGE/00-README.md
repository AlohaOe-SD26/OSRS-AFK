# PROJECT KNOWLEDGE — {{PROJECT_NAME}}

This folder is the project's brain. Any agent (or human) starting a session
reads here FIRST. Created by the Claude Code Project Kit on {{DATE}}.

## Reading order
| # | File | What it tells you | Type |
|---|------|-------------------|------|
| 1 | `04-HANDOFF.md` | Where we are RIGHT NOW + what's next | current-state |
| 2 | `01-VISION-AND-DESIGN.md` | What this program is for; intent of each part | current-state |
| 3 | `02-ARCHITECTURE.md` | How it's built; how to run it | current-state |
| 4 | `03-PUNCH-LIST.md` | The work queue | current-state |
| 5 | `05-KNOWN-ISSUES.md` | Open bugs and traps | current-state |
| 6 | `06-DECISIONS-LOG.md` | Why things are the way they are | append-only |
| 7 | `07-CHANGELOG.md` | Everything that has ever changed | append-only |

## File rules
- **Current-state files (01–05):** edit in place. They must always describe
  present reality — stale content gets removed, not preserved.
- **Append-only files (06, 07):** new dated entries go at the END. Past
  entries are never rewritten, reordered, or deleted.

## Definition of Done (summary)
Verified change → current-state docs updated → changelog/decisions appended
→ handoff updated → commit → push. Full version: see the managed block in
the project root's `CLAUDE.md`.
