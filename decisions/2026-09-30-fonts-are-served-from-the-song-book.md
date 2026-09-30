## 2026-09-30 — The fonts are served from the song book, not from Google

**Context:** The reveal.js night theme `@import`s Montserrat and Open Sans from fonts.googleapis.com. Every visitor's browser therefore asked Google for them — handing over its IP address — and the specs could not run without the internet.

**Decision:** The files Google serves (25 woff2, every subset) live in `style/fonts/` with their OFL licenses and a `fonts.css` that keeps Google's `@font-face` rules, `unicode-range` included. The two `@import` lines are removed from the vendored theme — the one change made to a vendored reveal.js file, to be repeated after an upgrade.

**Reasoning:** Keeping all subsets rather than picking Latin by hand keeps the behaviour exactly as it was: a browser still loads only the parts the page uses, and a song in a new script would not silently fall back. The slide-zoom specs measure exact values with these fonts and passed unchanged, which is the evidence that nothing renders differently.
