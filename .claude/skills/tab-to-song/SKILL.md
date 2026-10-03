---
name: tab-to-song
description: "Create a new song file for this guitar song book from an online chord/tab page (Ultimate Guitar and similar sites). Use this whenever the user gives a tab URL and asks to add, import, or convert it into a song here — including phrases like 'add this song from <url>', 'mach mir ein neues Lied aus diesem Tab', 'convert this tab', or when they paste an ultimate-guitar.com (or similar) link together with any request to add it to the songbook. Handles fetching the tab, converting column-aligned ASCII chord/lyric pairs into this project's inline `[Chord]` markdown format, and writing the file to content/songs/ in the right structure."
---

# Tab to Song

Converts an online chord/tab page into a new `content/songs/<Title> (<Artist>).md` file that matches this repo's format (see `CLAUDE.md` for the full spec). The hard part isn't fetching the page — it's re-aligning a monospace "chord line above lyric line" tab into this project's inline `[Chord]` notation. That algorithm is the bulk of this skill.

## Step 1 — Fetch the tab

Use WebFetch on the given URL. The thing to watch for: the chord/lyric block only makes sense as a fixed-width (monospace) block — chords are placed above lyrics by **column position**. If the fetched text has lost that alignment (chords bunched together, no gap before the word they belong to), the HTML→text conversion collapsed whitespace.

Fallback for Ultimate Guitar specifically: the raw HTML contains a `<div class="js-store" data-content="...">` element whose `data-content` attribute is a JSON blob with the exact original tab text at `store.page.data.tab_view.wiki_tab.content` (or `.wiki_tab.content` — path varies slightly by page type), with real `\r\n` and space characters preserved. If WebFetch's cleaned-up text looks misaligned, fetch the raw HTML (`curl` via Bash, or WebFetch asking for raw content) and pull the tab text out of that JSON field instead. This is the only reliable source of true column positions.

Also grab from the page: song title, artist, and any linked official video.

## Step 2 — Name the file

`content/songs/<Title> (<Artist>).md`. Use the title/artist as commonly known (match the source's own capitalization — this repo doesn't enforce strict title-casing, e.g. both "Baby one more time" and "Can't Help Falling in Love" exist side by side). Check `content/songs/` and `content/legacy-songs/` first — if a file for this song already exists, confirm with the user before overwriting rather than silently replacing their work.

## Step 3 — Add the `## About` tags

Put an `## About` section **first** (before the song's own sections), one tag per list item — these drive the table-of-contents tag filter (see `CLAUDE.md`). The source tab won't list tags, so infer them and keep the repo's vocabulary consistent:

- **Language** from the lyrics: `Deutsch`, `Englisch`, `Mundart` (Swiss German), …
- **Genre/kind** from the artist/style where clear: `Pop`, `Rock`, `Mantra`, …

```markdown
## About

- Englisch
- Pop
```

Add what you're confident about (at least the language), and name the tags you chose in your final summary so the user can adjust. Don't invent a genre you're unsure of — a language-only About is fine.

## Step 4 — Convert sections

Each bracketed section label in the tab (`[Verse 1]`, `[Chorus]`, `[Bridge]`, `[Intro]`, etc.) becomes an `## H2` heading. **Keep the tab's own section names and language** — don't translate "Chorus" to "Refrain" or renumber things; just carry over what the source uses.

## Step 5 — Convert chords: the core algorithm

This is the part that needs care. Read `references/chord-alignment.md` before doing this for the first time in a session — it has the full worked method with real examples, including how to handle contractions, compound words, dangling passing chords, and repeated lines that get denser harmonization on the second pass. Summary:

1. For each chord-line/lyric-line pair, find each chord's column position and match it to the nearest word start in the lyric line below it.
2. If the chord lands at or within ~1 character of a word's start, attach it as its own token with normal spacing: `[G] Bärge`.
3. If it clearly lands *inside* a word (2+ characters in, at a real morpheme boundary — a contraction like `s'Veh`, a compound like `Sunnestrahl`, an English contraction like `wouldn't`) fuse it with no spaces at that exact point: `s'[G]Veh`, `Sunne[G]strahl`, `woul[C]dn't`.
4. A chord with no word under it at all (a trailing passing chord, or a standalone chord between beats) becomes its own bracket token: `...rot! [G7]` or `[Dm] [E]`.
5. Never invent a chord that isn't in the source, and never drop one — every bracket in the chord line must end up somewhere in the output line.
6. Preserve directions and emphasis exactly as given: `_(x2)_`, `_(Repeat and add 2nd voice)_`, `**overlapping vocal**`, `~~replaced lyric~~`.
7. When the same lyric line repeats later with extra passing chords (very common in folk songs — the melody stays, the harmony thickens on repeat), keep that difference. Don't "clean it up" to match the first occurrence.
8. Keep the resulting line short enough — see "Line length" below before you finish converting a song with dense passing chords.

If a column position is genuinely ambiguous even after rounding, make the best call and say so briefly in your final summary rather than blocking on it — the user can spot-check and correct, same as they would with any other draft.

### Line length

`style/slide-zoom.js` auto-zooms each slide to fit its widest line — one overly long line shrinks the *entire* slide (title included), not just that line. A tab with lots of quick passing chords (e.g. a turnaround like `[F] [C]` at the end of every phrase, or a fill like `[C] [G]` mid-word) can easily produce a line 80-95 characters long once every chord is inlined, and that's visibly worse than the rest of the book: across the existing songs, no line with 3+ chords exceeds ~70 characters — most sit in the 40-60 range.

Before finishing, check: `awk -F'[][]' '{ n = (NF-1)/2; if (n >= 3) print length($0), n }' "content/songs/<file>.md" | sort -rn` and compare against the same command run over a couple of existing songs. If your lines run noticeably longer, split them — almost always at a spot the source tab already marks for you: a comma, or the wide gap the original ASCII tab left for a breath/rest. Move a trailing dangling passing-chord pair (like the `[F] [C]` turnaround at a phrase's end) onto the next line rather than tacking it onto the end of an already-long line — this is the same "standalone bracket token" convention from point 4, just given its own line when the line is otherwise full. Lines split this way are still the same stanza (no lyrical break, just a wrap for width), so don't insert a blank line between them — a blank line means an actual new stanza/repeat elsewhere in this format.

## Step 6 — Resources section

```markdown
## Resources

- [Song](<official or lyric video>)
- [Source tab](<the URL you were given>)
- [Guitar tutorial](<optional>)
```

Only ever link a URL you actually found (on the tab page, via a real web search you ran, or one the user gave you) — never fabricate a plausible-looking YouTube link. If you can't confidently find an official video, ask the user or just omit the `Song` line rather than guess. A `Source tab` entry is required — that's the URL you were given.

Note: at build time, `## About` and `## Resources` (and an `## Instructions` section, if the song has one) are merged into a single `## About` slide at the front, with the tags rendered as `Sprache:`/`Genre:` bullets in the Resources list — this is automatic (`merge_about_section` in `lib/build_helpers.rb`); keep writing them as separate sections here, same as always.

## Step 7 — Write and offer to build

Write the file. Then offer to run `./build` (fast) so `index.html`/`print.html` pick up the new song — don't run `./build --deploy` unless asked, since that publishes externally.
