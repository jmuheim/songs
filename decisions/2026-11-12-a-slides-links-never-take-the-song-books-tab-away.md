## 2026-11-12 — A slide's links never take the song book's tab away

**Context:** Each song's „Infos über das Lied" slide links to YouTube (the song, tutorials, interpretations) and to its tab source, nearly all of them Ultimate Guitar. They opened in the song book's own tab. Coming back meant loading the book anew: slow on a slow connection, impossible without one. Browsers often keep a page with an open WebSocket, a session's, out of the back/forward cache, so in a session that reload was the rule. The user plays on the move, often with a poor connection.

**Decision:** At build time (`external_links`, `post_process_index`), a YouTube watch link gets its embedded player's address on `youtube-nocookie.com` as `data-video`. A click plays it in a `<dialog>` of the song book's own (`#video-modal`), whose iframe is created on opening and removed on closing. Every other external link gets `target="_blank" rel="noopener"`. `print.html` is left as it was.

**Reasoning:**
- **Why not frame everything:** a dialog for every link would keep the reader in the book best, but YouTube's watch pages (`X-Frame-Options: SAMEORIGIN`) and Ultimate Guitar (`frame-ancestors 'self' …`) refuse to be framed. Only YouTube's embed addresses allow it, so the dialog is for videos only, and the rest get a tab of their own.
- **Why not Reveal's lightbox:** reveal.js has one (`data-preview-link` with an address of its own), and it was the user's first thought. It was rejected:
  - its iframe has no `allowfullscreen`, so the video could not go full screen;
  - its header buttons carry no label, and its error message is English;
  - its state is part of `Reveal.getState()`, so a follower's `Reveal.setState` (`body-controls.html`) closes it with every step of the scroller.

  A native `<dialog>` is how the song book does every other overlay already: it keeps its keys from Reveal, closes on Esc and on its backdrop, and focuses its title.
- **Why nocookie:** `youtube-nocookie.com` sets no cookie until the video plays. It keeps the book's stance of sending visitors to Google for nothing they didn't ask for, like the self-hosted fonts.
- **Why `autoplay=1`:** the click already asked for the video.
- **Why the player is removed on closing:** it stops the sound and leaves nothing loading in the background, which matters most on a slow connection.
