## 2026-11-26 — Scrolling the table of contents brings the corner buttons back

**Context:** The corner buttons fade out and come back on a tap, a moving mouse or the keyboard's focus, but not on a swipe (see [the corner buttons fade out](2026-10-31-the-corner-buttons-fade-out-and-come-back-on-a-tap.md)). At an evening of singing, the user scrolled through the table of contents looking for the next song and found the buttons gone: a scroll of the list is a swipe too, and the list is mostly links, where a tap brings nothing back either.

**Decision:** A scroll of the table of contents (a `scroll` on `section#TOC`, heard in the capture phase, since it doesn't bubble) brings the buttons back, to fade again as after a tap.

**Reasoning:** The swipe was left out because it pages: the buttons would be up on every slide while a song is read. Scrolling the table of contents pages nothing. It is where a song is picked, and where 🔥 (to start live scrolling) or ⚙️ is wanted. The earlier worry that 📖 and ↕️ cover the filter bar's ends on the TOC still holds for a tap on the filter, which brings nothing back. The user accepted it for a scroll, which moves the list under the bar rather than working the bar itself.
