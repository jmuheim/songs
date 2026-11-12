## 2026-11-12 — A new build offers itself in a dialog

**Context:** With the service worker ([the song book opens from a service worker's cache](2026-11-12-the-song-book-opens-from-a-service-workers-cache.md)), a deploy shows only from the second visit after it, and that entry left out any notice: the next visit would show the new build anyway. In practice, whoever deploys checks the result on a phone right away, sees the old build, and has to open the book a second time without being told why. A first version offered the reload in the toast along the bottom edge, with a button „Neu laden" that stayed 20 s. The user wanted a proper, dominant dialog instead, one that can't be missed.

**Decision:** When a new worker takes over a page it already controlled, `#update-modal` opens: „Neue Version", with „Später" and „Neu laden". „Neu laden" writes the current slide into the URL and reloads. „Später", Esc or the backdrop close it, and the next visit shows the new build. The first worker on a device takes over too, but brings no new build, so it shows nothing.

**Reasoning:**
- **Why not the toast:** it is easy to miss. It fades after a few seconds, and a session's toast arriving meanwhile replaced it. Its button also had to fit on the line of a strip made for a sentence or two.
- **What the dialog costs:** it interrupts. Over a follower's screen in the middle of a song it covers the lyrics until it is answered. A deploy during an evening is rare, and one tap answers it, so that was accepted.
- **Why not reload by itself:** the reader chooses the moment, never the song book. The session and the slide would survive a reload, but a reload in the middle of a song is no surprise to spring.
