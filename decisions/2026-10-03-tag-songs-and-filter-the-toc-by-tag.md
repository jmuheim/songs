## 2026-10-03 — Tag songs via a per-song `## About` list and filter the TOC by tag

**Context:** The table of contents is one flat list and grows with the collection. We wanted to categorise songs (language and genre — `Deutsch`, `Englisch`, `Mundart`, `Pop`, `Rock`, `Mantra`, …) and narrow the TOC to one or more of those categories.

**Decision:** Tags live in a visible `## About` section at the top of each song, one tag per markdown list item. The build parses them (`song_tags`), carries them into the TOC as a `data-tags` attribute per `<li>` and a chip bar (`inject_toc_filter`), and `style/toc-filter.js` filters the list in place. Several selected tags combine with **OR**; „Alle" clears. The `## About` section is stripped from `print.html` like `## Resources`.

**Reasoning:**

- **Storage as a visible `## About` list**, over per-song YAML front matter or an HTML comment (both offered). The owner writes these files by hand and wanted the tags *visible* — they render as a short slide right after the song title. A markdown list needs no new syntax and no front-matter stripping before the songs are concatenated, and `validate_song!` already accepts it (it is just another H2).
- **Match TOC entries to songs by document order**, not by re-deriving Pandoc's header slugs. Pandoc's slugifier is finicky (it drops the leading digits of "74-75", strips emoji/flags from titles like "… (Traditionell 🇨🇭)"), so reproducing it in Ruby would be fragile. The TOC lists the Introduction first, then songs in the same sorted order the build reads them — so zipping `li[1..]` with the parsed tag arrays is exact and needs no slug maths.
- **Chips rendered server-side (Nokogiri), not built at runtime by JS.** Keeping the markup in the generated HTML lets the golden `spec/fixtures/golden/toc.html` pin it and keeps the page working without JS; the script only wires clicks. This matches how the rest of the pipeline is tested.
- **OR, not AND.** Tags mix language and genre; OR is the forgiving default for a flat tag cloud, and selecting two genres still shows something. Untagged entries (incl. the Introduction) hide while any filter is active — a filter that still showed untagged songs would defeat the point.
- **Filter state is local to each client and not synced over multiplex.** Multiplex syncs slide indices for a live-scroll session; how someone browses the TOC on their own device is theirs, and the session lands everyone back on the (unfiltered-by-others) TOC anyway.
- **Consequence accepted:** `## About` at the top adds one vertical slide between each song's title and its first content slide. That was the owner's explicit "at the top" choice; it is why `go_to_first_song` in the browser specs now targets v=2.
