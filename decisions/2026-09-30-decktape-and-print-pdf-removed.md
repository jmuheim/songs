## 2026-09-30 — DeckTape and print.pdf removed; print.html is printed from the browser

**Context:** `./build --pdf` ran DeckTape over `print.html` to produce the committed `print.pdf` (6.9 MB). The song book no longer needs a PDF, and DeckTape no longer finished the job either: even on unchanged `master` it aborted at slide 238 of 395 with „Attempted to use detached Frame".

**Decision:** Remove DeckTape, the `--pdf` flag and `print.pdf`. `print.html` stays: it is still built and specced, and opening `print.html?print-pdf` in Chrome and printing lays out every slide as a page of its own (395 slides on 399 pages in a headless check).

**Reasoning:** Without its generator, a committed PDF could only go stale. The browser's own print path needs no Node dependency and already works.
