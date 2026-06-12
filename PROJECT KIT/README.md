# Claude Code Project Kit

A portable, drop-in folder that bootstraps ANY project (new or existing) for
agent-resumable work with Claude Code: standing directives, a PROJECT
KNOWLEDGE doc system, GitHub integration, and the Remote-Start phone launcher.

## What's in the kit
```
PROJECT KIT\
├── Bootstrap-Project.bat        <- double-click this
├── Bootstrap-Project.ps1        <- the installer (knobs at the top)
├── README.md                    <- this file
├── REMOTE START\                <- phone-access launcher (bundled)
│   ├── Remote-Start.bat
│   └── Remote-Start.ps1
└── templates\
    ├── CLAUDE.md                <- standing directives (managed block)
    └── PROJECT KNOWLEDGE\       <- 00-README ... 07-CHANGELOG skeleton
```

## How to use (every project)
1. Copy the whole `PROJECT KIT` folder into the project's ROOT folder.
2. Double-click `Bootstrap-Project.bat`.
3. Answer the one prompt (GitHub repo name), done.

That's it — the project root is auto-detected as the kit folder's parent.
The bootstrap is **idempotent**: re-running it never overwrites your files;
it only creates missing pieces and refreshes the managed directives block in
CLAUDE.md (with a `.bak` backup whenever it touches an existing file).

## What the bootstrap installs
1. **`CLAUDE.md`** — standing directives Claude Code auto-loads every
   session: maintain project status, append to the changes/fixes log,
   document intent (whole program + each part), keep the handoff doc
   current, and a per-work-item Definition of Done that ends in
   commit + push. The directives live between
   `<!-- BEGIN/END PROJECT-KIT DIRECTIVES -->` markers; everything you
   write outside the markers is yours and never touched.
2. **`PROJECT KNOWLEDGE\`** — `00-README` (reading order),
   `01-VISION-AND-DESIGN`, `02-ARCHITECTURE`, `03-PUNCH-LIST`,
   `04-HANDOFF`, `05-KNOWN-ISSUES` (current-state, edited in place) and
   `06-DECISIONS-LOG`, `07-CHANGELOG` (append-only history).
3. **`REMOTE START\`** — the portable phone-access launcher.
4. **Git + GitHub** — `git init` (branch `main`) and a starter
   `.gitignore` if missing; then, if the `gh` CLI is logged in, creates a
   **private repo on your profile** (name prompted, folder name suggested)
   and sets it as `origin`; otherwise asks you to paste a manually created
   repo URL (or skip). The repo URL is recorded in `04-HANDOFF.md`, and an
   initial commit is pushed.

## Existing projects — what happens to files you already have
- An existing `CLAUDE.md` is preserved: the directives block is appended to
  it (backup saved as `CLAUDE.md.bak`). On later re-runs the block is
  updated in place between its markers.
- Existing `PROJECT KNOWLEDGE` files are skipped, never overwritten — only
  missing ones are created. Same for `.gitignore`, the launcher, and an
  already-configured `origin` remote.
- If you already seeded PROJECT KNOWLEDGE with different filenames, either
  rename to the kit's scheme or keep yours — the bootstrap will just add
  whichever of the eight standard files are missing.

## One-time GitHub CLI setup (do once per PC)
1. Install: open PowerShell and run
   ```powershell
   winget install GitHub.cli
   ```
   then close and reopen PowerShell so `gh` is on PATH.
2. Log in with the device flow:
   ```powershell
   gh auth login
   ```
   Choose: **GitHub.com** -> **HTTPS** -> authenticate Git with your GitHub
   credentials: **Yes** -> **Login with a web browser**. Copy the 8-character
   one-time code it shows, press Enter, and paste the code at the
   `github.com/login/device` page that opens. Approve.
3. Verify:
   ```powershell
   gh auth status
   ```
   It should report you're logged in to github.com. The bootstrap checks
   this exact command before trying to create repos.
4. If you've never used git on this PC, also set your identity once:
   ```powershell
   git config --global user.name  "Your Name"
   git config --global user.email "you@example.com"
   ```

## Knobs (top of Bootstrap-Project.ps1)
- `$LevelsUp` — 1 (default) when the kit sits in a subfolder of the project
  root; 0 if its files sit directly in the root.
- `$ManualProjectPath` — hard-override the project root entirely.
- `$DefaultBranch` — branch name for new repos (default `main`).

## How agents stay in sync (the contract)
Every Claude Code session in a bootstrapped project automatically:
1. Reads `PROJECT KNOWLEDGE\04-HANDOFF.md` first to resume where the last
   agent left off.
2. Keeps current-state docs true while working.
3. Finishes every work item with: docs updated -> changelog/decisions
   appended -> handoff updated -> commit -> push.

So at any moment, a brand-new chat (PC or phone via Remote-Start) lands with
full context and a pushed repo. The kit folder itself is committed with the
project, so the bootstrap travels with the repo — add `PROJECT KIT/` to
`.gitignore` if you'd rather keep it local.
