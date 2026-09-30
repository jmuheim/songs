## 2026-09-30 — The URL is written the moment the page is hidden

**Context:** Reveal writes the slide into the URL at most once a second (Safari limits `replaceState` calls), and iOS stops that timer when a page goes to the background and likes to discard such pages. A phone switched to another app right after a slide change kept the old hash, and its reload landed a slide early.

**Decision:** On `visibilitychange` to `hidden`, the current slide is written into the URL at once — one call per switch, far from any limit.

**Reasoning:** Taken over from Axipedia. Following clients are corrected by the next repeat anyway; the fix matters for those browsing freely, whose place nothing else restores.
