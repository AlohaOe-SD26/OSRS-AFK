# Decisions Log — {{PROJECT_NAME}}
> APPEND-ONLY. New entries at the end. Never rewrite history — if a decision
> is reversed, append a NEW entry that supersedes the old one and says so.

---

## {{DATE}} — Adopted the Claude Code Project Kit
- **Decision:** Standardize on the kit's CLAUDE.md directives + PROJECT
  KNOWLEDGE structure + per-item commit/push definition of done.
- **Context:** Make every session resumable by any agent with zero context.
- **Alternatives rejected:** Ad-hoc per-chat context pasting (doesn't scale,
  loses history).
