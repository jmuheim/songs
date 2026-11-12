## 2026-11-12 — The song book opens from a service worker's cache

**Context:** The song book is played on the move, often on a slow connection or none. Once loaded, everything is in the page. But every load asked the server first: `index.html` and every script under the `no-cache` headers ([Cache headers](../CLAUDE.md#cache-headers)), so a reload waited for a round trip per file, and without a connection it failed. Each of these is such a load: a reload, a tab iOS discarded in the background, the home-screen app started, a QR code scanned.

**Decision:** A service worker (`sw.js`, written by `./build` from `lib/service-worker.js`) keeps the page and every script and stylesheet it loads, and serves them cache-first. Any navigation to the page, whatever its query (`?live=`), gets the kept `index.html`. Fonts and pictures are kept as they are first asked for. The file list is read off the built page itself. `VERSION` is a hash of the page and the files, so a new build changes `sw.js`. The browser finds the new worker on the next visit, and the worker fetches the new files in the background, takes over at once (`skipWaiting`, `clients.claim`) and deletes the old cache. `./dev` builds without it, and its page unregisters any worker left over.

**Reasoning:**
- **Why cache-first:** network-first with a timeout would have shown a new build at once when the connection is good. But every load on a slow connection would then wait out the timeout, and that is exactly the case this is for. Cache-first answers at once and costs one thing: a deploy shows from the second visit on, not the first.
- **Why no „neue Version" toast:** a toast saying a new version is ready was left out for now. It would only tell the reader to reload, which the next visit does anyway.
- **Why `skipWaiting`:** waiting for every tab to close would leave an iPhone, whose tabs never close, on an old build for weeks, the very thing the `no-cache` headers were meant to end.
- **What `skipWaiting` costs:** a page already open is served by the new worker from then on. It could get a file of the new build beside its old `index.html`. That needs the update to finish while the page is still loading its scripts, which come from the cache in milliseconds, so it was accepted.
- **Why the file list is generated:** a hand-kept list would fall behind the page the first time someone adds a script.
- **Why `no-cache` stays:** the headers still matter for a first visit and for the worker's own update fetches, which ask with `cache: 'no-cache'` so an unchanged file costs only a 304.
- **Why not in `./dev`:** a worker there would serve its cache to browser-sync's reloads.
