# osrs_afk â€” Claude Code Project Instructions

Anything you write OUTSIDE the marked block below is yours and will never be
touched. The Project Kit bootstrap only manages the text BETWEEN the
BEGIN/END markers (re-running Bootstrap-Project updates that block in place).

<!-- BEGIN PROJECT-KIT DIRECTIVES (managed block â€” re-run Bootstrap-Project to update; do not hand-edit inside) -->
## Standing Directives (Project Kit)

These rules apply automatically to EVERY session in this project, with no
prompting needed. They exist so that any AI agent â€” in any future chat â€” can
pick up exactly where the last one left off.

### 1. Session start â€” orient before acting
- Read `PROJECT KNOWLEDGE/00-README.md` (reading order), then
  `PROJECT KNOWLEDGE/04-HANDOFF.md` for current state, in-progress work, and
  next steps. Treat the handoff as the authoritative "you are here" marker.
- Skim `03-PUNCH-LIST.md` and `05-KNOWN-ISSUES.md` before proposing or
  starting work, so effort goes to agreed priorities and known traps are
  avoided.
- Never re-derive project intent from code alone. `01-VISION-AND-DESIGN.md`
  is the source of truth for what this program (and each part of it) is FOR.
  If code and vision conflict, flag it â€” don't silently pick one.

### 2. Documentation duties (continuous, not optional)
- **Project status** â€” keep `04-HANDOFF.md` continuously current: what state
  the project is in, what just changed, what is mid-flight, what comes next.
- **Changes & fixes log** â€” every meaningful change, fix, or addition gets an
  entry appended to `07-CHANGELOG.md`.
- **Intent & goals** â€” keep `01-VISION-AND-DESIGN.md` accurate for both the
  whole program and each individual component. When a new component is built,
  add its purpose/intent there before or with the code.
- **Decisions** â€” any significant choice (architecture, library, tradeoff,
  scope) gets appended to `06-DECISIONS-LOG.md` with rationale and the
  alternatives that were rejected.
- **Punch list** â€” keep `03-PUNCH-LIST.md` statuses true at all times.

File-handling rules:
- `01`, `02`, `03`, `04`, `05` are CURRENT-STATE files: edit them in place so
  they always describe present reality. Remove stale content.
- `06` and `07` are APPEND-ONLY history: add new entries at the end with a
  date. Never rewrite, reorder, or delete past entries.

### 3. Definition of Done â€” every completed work item
A work item (feature, fix, refactor, asset) is NOT done until all of these
are complete, in order:
1. The change works and has been verified (run it / test it as applicable).
2. Current-state docs updated: `01`/`02`/`05` as applicable; the item's entry
   in `03-PUNCH-LIST.md` marked done.
3. `07-CHANGELOG.md` entry appended; `06-DECISIONS-LOG.md` appended if any
   significant decision was made.
4. `04-HANDOFF.md` updated (current state, next steps).
5. `git add -A` and commit, message format:
   `<type>: <short summary> (punch-list #N)` â€” types: feat/fix/refactor/docs/chore.
6. `git push`. If the push fails (offline, no remote yet), record the fact
   under an "Unpushed work" note in `04-HANDOFF.md` so the next session
   pushes first.

Do steps 2â€“6 per completed item, not batched at the end of a long session.

### 4. Handoff quality bar
Another agent with ZERO prior context must be able to resume from
`04-HANDOFF.md` alone. It must always answer: What is this project? What
state is it in right now? What was just done? What is in progress (and how
far along)? What is next? How do I run/build/test it? Any gotchas or
unpushed work?

### 5. Git conduct
- The remote repository URL is recorded in `04-HANDOFF.md`.
- Commit per completed work item; keep commits scoped and messages honest.
- Never force-push; never rewrite published history; never commit secrets
  (.env files, API keys, tokens).
- Ask before any destructive git operation (reset --hard, clean -f, branch
  deletion).
<!-- END PROJECT-KIT DIRECTIVES -->

## Session Protocol (project-specific — permanent)

This section is hand-maintained and lives OUTSIDE the managed block. It
EXTENDS the Project Kit directives above; where the two overlap (session
start, Definition of Done), THIS section is the authoritative, more specific
version. CLAUDE.md stays protocol-only (how to work); project STATE lives in
`PROJECT KNOWLEDGE/` and nowhere else.

### 1. Session start — the knowledge base is the source of truth
On session start, read `PROJECT KNOWLEDGE/04-HANDOFF.md` →
`03-PUNCH-LIST.md` BEFORE doing anything. The `PROJECT KNOWLEDGE/` folder is
the source of truth; current-state files (`01`–`05`) are edited in place so
they always describe present reality.

### 2. Command word — "wrap up"
When the user says **"wrap up"**, end the session safely:

- **(A) Honest stopping point.** If the remaining work can be finished AND
  verified green quickly (suite + all three gates:
  determinism / save-load / offline), finish and commit it normally. If
  not, park it honestly: NEVER push red/unverified work to `main` — revert
  it from `main` and preserve it on a clearly-named WIP branch (or whatever
  is cleanest), and write the exact debug state into `04-HANDOFF.md`:
  what's failing, what was tried, measured results, and the leading
  hypothesis, so the next session resumes the debug without rediscovery.
- **(B) Record new directives.** Any new directives the user gave this
  session become punch-list items with their FULL specs
  (`- [ ] #N — description`, N never reused). Do NOT implement them during
  wrap-up.
- **(C) Cold-resume docs.** Update `04-HANDOFF.md` and `03-PUNCH-LIST.md`
  so a cold session with zero context can resume: current state, exact
  next steps in order (including any parked debug), and where new items
  sit in the build order.
- **(D) Push everything.** Commit and push EVERYTHING — code, docs, punch
  list. Nothing may exist only on the local machine. The final report must
  confirm the push succeeded (commit hash + branch).

### 3. Command word — "pick up where you left off"
Read `04-HANDOFF.md` and `03-PUNCH-LIST.md`, VERIFY the working tree
actually matches the handoff's claimed state (run the suite if in doubt —
trust but verify), then resume the handoff's "Next steps" in order.

### 4. Standing discipline (all work, not just wrap-up)
- **Per-item Definition of Done:** suite green + determinism/save-load/
  offline gates green + render parses + docs updated (changelog, decisions
  log, punch list, handoff) + commit and push — PER COMPLETED WORK ITEM,
  not batched at the end of a session.
- **Save-shape discipline:** any save-shape change bumps `SAVE_VERSION`
  with an upgrader appended to `SaveLoad._chain()` — never ship a schema
  change without one.
- **Diagnose before tuning:** no knob-reactions to single-seed noise;
  tuning decisions take multi-seed sweeps (single-seed before/after is
  RNG-confounded).
- **Decisions log:** record design decisions with rationale AND the
  rejected alternatives in `06-DECISIONS-LOG.md` (append-only).
