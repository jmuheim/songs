## 2026-09-30 — The overview and a pause stay on the presenter's screen

**Context:** The presenter sent `Reveal.getState()` as it was, `overview` and `paused` included. Opening the overview (Esc) to find the next song put every phone into the tile grid and walked it through each step of the search; B blacked out every phone.

**Decision:** Only the slide's indices are sent. While the overview is open, the presenter repeats the slide it was opened on; the slide chosen goes out when it closes. `paused` is never sent.

**Reasoning:** The audience needs to know where the song is, not how the presenter is looking for it — and a tile grid on a phone is unreadable anyway. Axipedia does the same with its overview (a sign of life without a slide). A paused screen is the presenter's business: on a phone at a campfire, a black screen only looks broken.
