---
name: songs-log-decision
description: Record a project decision as its own file under decisions/ (the committed decision log described in DECISIONS.md), so the reasoning travels with the repo instead of living only in a chat or someone's memory. Use when the user asks to log/record a decision, note why something was changed, or "write this down so we don't forget". The optional argument is a one-line summary of the decision; if omitted, derive it from the conversation.
---

# Log a project decision

Goal: capture **why** a non-obvious choice was made, in a file committed to the repo. Facts the code, the git history, `CLAUDE.md` or `README.md` already record do **not** belong here — only the reasoning that isn't derivable from them. See [`DECISIONS.md`](../../../DECISIONS.md) for the convention this skill follows.

## 1. Figure out what to log

- If the user gave an argument, that's the decision summary.
- Otherwise derive it from the conversation: what was chosen, what alternatives were rejected, and why.
- One concrete decision per entry. If several unrelated decisions came up, write several files.
- If it's genuinely unclear what to record, ask one short question rather than guessing.

## 2. Get today's date

Use the current date from the session context. If unsure, run `date +%F`. Never invent one.

## 3. Write the entry as a new file

**One entry, one file. Never append to an existing entry, and never add the entry to a list anywhere.** That is the whole point of the layout: two branches each writing a decision touch two different files, so the merge has nothing to resolve. A shared, prepended-to list — what this replaced — conflicted on nearly every merge.

Path:

```
decisions/YYYY-MM-DD-short-lowercase-slug.md
```

The slug comes from the title: lowercase, umlauts spelled out (`ä` → `ae`), no special characters, words joined by hyphens, roughly 60 characters at most, cut on a word boundary. **No running number** — a counter is exactly the thing two branches would set identically.

Content — the heading is `##`, not `#`, so the files still concatenate into one log:

```markdown
## YYYY-MM-DD — <short title>

**Context:** <what prompted it — the problem, the trigger>

**Decision:** <what was decided>

**Reasoning:** <why this way and not another; what was rejected and why>
```

Write in English, like the rest of the repo's docs and the existing entries (unless the user wrote the decision in another language).

Nothing else needs updating: there is no index, and `DECISIONS.md` is a static explanation of the convention, not a table of contents.

## 4. Refer to other entries by file, never by position

"The entry above" / "two entries down" break the moment anything is inserted, and across separate files they mean nothing. Link the file instead — paths are relative to `decisions/`, since that is where both live:

```markdown
… as in [CI runs the specs on every push](2026-09-30-ci-runs-the-specs-on-every-push.md) …
```

## 5. Report, don't commit

Show the user the entry you added. Do **not** `git commit` or push unless the user explicitly asks — they review the diff first, as with the other skills in this repo.
