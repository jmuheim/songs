// The song book's service worker: ./build writes it as sw.js beside
// index.html (service_worker in lib/build_helpers.rb fills in VERSION and
// FILES), and index.html registers it. It keeps the page and the files it
// loads on the device, so the song book opens, reloads and takes a QR
// code's ?live= without the network, at once even on a slow one.
//
// A new build has another VERSION, so its sw.js differs, which the browser
// notices on the next visit: the new worker fetches the new files in the
// background, takes over, and drops the old ones. The page shown meanwhile
// stays as it was; the new one shows from the next load on.
const VERSION = '{{version}}';
const FILES = {{files}};
const CACHE = 'songs-' + VERSION;
const PAGE = new URL('index.html', self.location).href;
// The song book's own addresses: the page, by its name or its folder's
const PAGES = [new URL('./', self.location).pathname, new URL(PAGE).pathname];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      // no-cache: asked anew (an unchanged file comes back as a cheap 304), so
      // a file the browser's own cache still holds from the last build isn't
      // taken for this one's
      .then(cache => cache.addAll([PAGE].concat(FILES).map(url => new Request(url, { cache: 'no-cache' }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key.startsWith('songs-') && key !== CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  // Not the relay's socket, nor YouTube: only the song book's own files
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (request.mode === 'navigate') {
    if (!PAGES.includes(url.pathname)) return;
    // Whatever the query: ?live= from a QR code is read by the page itself
    event.respondWith(caches.open(CACHE).then(cache => cache.match(PAGE)).then(hit => hit || fetch(request)));
    return;
  }
  // The rest as it is first asked for, kept: the fonts (only those a page
  // uses), the pictures in ⚙️ and the Vollbild runway
  event.respondWith(caches.open(CACHE).then(cache =>
    cache.match(request).then(hit => hit || fetch(request).then(response => {
      if (response.ok) cache.put(request, response.clone());
      return response;
    }))
  ));
});
