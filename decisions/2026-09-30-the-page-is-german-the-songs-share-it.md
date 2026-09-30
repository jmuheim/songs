## 2026-09-30 — The page is German; the songs share its language

**Context:** `<html>` carried no `lang`, so screenreaders and hyphenation guessed. The songs are in English, German and Swiss German dialect.

**Decision:** The front matter sets `lang: de-CH` for the whole page. No `lang` per song.

**Reasoning:** The page's own words — dialogs, status line, introduction — are German with Swiss spelling. A language per song was considered and not wanted for now; the page-wide value is what a screenreader needs to pick a voice at all.
