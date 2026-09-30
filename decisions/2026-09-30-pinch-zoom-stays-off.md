## 2026-09-30 — Pinch-zoom stays off

**Context:** Pandoc's revealjs template sets `user-scalable=no, maximum-scale=1.0`, which blocks pinch-zoom — a WCAG 1.4.4 concern, and the song book is read mostly on phones.

**Decision:** Leave it as it is.

**Reasoning:** The automatic zoom is enough: `style/slide-zoom.js` already scales every slide to fill the screen, so the lyrics are as large as the phone allows.
