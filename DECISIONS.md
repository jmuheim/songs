# Decision log

Short, dated notes on decisions that are not obvious — the *why* behind a change, which neither the code nor the git history tells.

**The entries live in [`decisions/`](decisions/), one file per entry.** There is deliberately no index here: a maintained list would be one file every branch appends a line to, and two branches doing so collide on every merge. One file per entry means two branches never touch the same file. For an overview, sort `decisions/` by name or search the text.

## File name

```
decisions/YYYY-MM-DD-short-lowercase-slug.md
```

The date of the decision, then a slug of the title: lowercase, no special characters, words joined by hyphens, around 60 characters at most. No running number — that is exactly the kind of counter two branches set to the same value.

## Structure

```markdown
## YYYY-MM-DD — <short title>

**Context:** <what prompted it — the problem, the trigger>

**Decision:** <what was decided>

**Reasoning:** <why this way and not another; what was rejected and why>
```

The heading is `##`, not `#`, so the files can be concatenated as they are. Refer to another entry by linking its file, never by position („the entry above").
