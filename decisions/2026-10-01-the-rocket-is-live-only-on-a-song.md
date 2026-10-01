## 2026-10-01 — 🚀 is live only on a song

**Context:** 🚀 would start a live-scroll session from any slide — the title, the table of contents, the introduction included. But a session is always *about* one song: the scroller is locked to it and everyone else is snapped onto it. Starting one off a song produced a session about a non-song.

**Decision:** 🚀 is disabled unless the current horizontal slide is a song (not `title-slide`, `TOC` or `introduction`). While a session runs it stays enabled, because then it ends the session — and the scroller is always on a song anyway.

**Reasoning:** Disabling says "not here" up front, rather than letting the presenter open something meaningless (a session locking the room onto the TOC). Keeping it enabled mid-session is required so the session can always be ended. The song test reads the slide's slug — which, for a slide with sub-slides, pandoc puts on the stack section's first child, not on the stack itself (`slideId`); the title and TOC have no sub-slides, so their id sits on the section. Builds on [live-scroll sessions, presenter delegates to a guest](2026-09-30-live-scroll-sessions-presenter-delegates-to-a-guest.md).
