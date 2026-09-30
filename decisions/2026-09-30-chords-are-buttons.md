## 2026-09-30 — Chords are buttons

**Context:** The chord fingerings (clickable chords, #39) opened on a click only: the chords were plain `<code>` elements, unreachable by keyboard and not announced as anything that can be pressed.

**Decision:** `chords.js` makes each chord a button (`role="button"`, `tabindex="0"`, `aria-expanded`, `aria-controls`). Enter or Space opens and closes the fingering, which is read out as it appears. Space follows the rule for buttons: from the keyboard it presses the chord, after a mouse click it turns the page.

**Reasoning:** The markup stays Pandoc's `<code>`, so `print.html` and the golden fixtures are untouched and only the interactive page gains the behaviour. Every chord on a slide becomes a Tab stop, which is many; that is what the feature is, and only the current slide is reachable (see [reveal.js 6.0.2](2026-09-30-reveal-js-6-0-2-vendored-as-five-files.md)). The key handler listens on `window`, after Reveal's on the document, so it can tell a key Reveal already used from one meant for the chord.
