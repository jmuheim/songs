# My Songs

A collection of songs I perform on guitar. Written in Markdown with inline chord notation, compiled into an interactive Reveal.js slideshow and a print-friendly version.

A live version is at [songs.josh.ch](https://songs.josh.ch).

## Features

- Swipe left/right to change songs, up/down to navigate song sections; on a computer, click the chevrons at the screen edges or use the arrow keys
- Colour-coded chords (each root letter gets its own colour)
- Each song slide ends on a small „Next: …" preview of the next slide's heading and first line (or „Ende des Lieds" on the last one), fading in a few seconds after the slide appears, so whoever scrolls can read ahead
- Dark/bright theme and chord visibility, both in the ⚙️ Settings dialog
- Full screen with ↕️, top right, and back with another press. On an iPhone, where Safari has no full-screen mode for a web page, it asks for one swipe down instead: that makes Safari hide its bars, and they stay hidden while you page through the songs. Added to the home screen (Share › „Add to Home Screen"), the song book opens without any bars at all
- Tag songs (language, genre, …) and filter the table of contents by tag
- **Live sync** — open the song book on your phone and follow along as the presenter, or a volunteer, scrolls the current song (see below)
- Print-friendly version: open `print.html?print-pdf` in Chrome and print

## Installation

- [Ruby](https://www.ruby-lang.org/) 3.x
- [Pandoc](https://pandoc.org/): `brew install pandoc`
- [fswatch](https://github.com/emcrisostomo/fswatch) (dev watch only): `brew install fswatch`
- [browser-sync](https://browsersync.io/) (dev watch only): `npm install -g browser-sync`
- [Node.js](https://nodejs.org/) 18+ (tests only)

## Build

```bash
./build           # Build index.html and print.html
./build --deploy  # HTML + deploy to songs.josh.ch (manual fallback)
./dev             # Watch, rebuild, and live-reload on every change (local only)
```

The usual way to publish is **not** `--deploy`: a push to `master` deploys to songs.josh.ch from CI once the tests pass (`.github/workflows/test.yml`).

> Song files contain non-ASCII characters; `build` sets `LANG` and the UTF-8 encoding itself, so no `LANG=…` prefix is needed.

> **Dev note:** `./dev` runs browser-sync with `--no-ghost-mode`. Ghost mode (enabled by default) syncs clicks across all open tabs, which interferes with the multiplex feature — every button press would appear to fire on all "clients" simultaneously during local testing.

## Tests

```bash
npm install --prefix multiplex-server   # once
bundle exec rspec
```

The browser specs run their own multiplex server on `127.0.0.1:18889`, so a spec that logs in as host never broadcasts through the relay songs.josh.ch uses.

GitHub Actions runs the whole suite on every push to `master` and on every pull request (`.github/workflows/test.yml`). A green run on `master` then deploys to songs.josh.ch.

## Adding songs

Add a Markdown file to `content/songs/`, named after its own H1: lowercase the `Title - Artist` heading, drop any `.`/`,`/`'`, transliterate umlauts (`ä`→`ae`, `ö`→`oe`, `ü`→`ue`, `ß`→`ss`), and turn spaces into underscores, e.g. `# Kiss the Earth - Ajeet` → `kiss_the_earth_-_ajeet.md`, `# Über den Wolken - Reinhard Mey` → `ueber_den_wolken_-_reinhard_mey.md`. Drop the artist (just `Title`, no file suffix) for a traditional/folk song with nobody specific to credit. Chords go inline as `[Am]`, `[G7]`, etc.

Every song needs an `## Infos über das Lied` section at the top with its Sprache (language) and Genre tags plus its resource links, one per list item:

```markdown
# Kiss the Earth - Ajeet

## Infos über das Lied

- Sprache: Englisch
- Genre: Mantra
- [Lied auf YouTube](https://youtube.com/...)

## Verse 1

...
```

The tags and links show on the song's „Infos über das Lied" slide (together with, if present, an Instructions section — see `CLAUDE.md`) and drive the Sprache/Genre filter dropdowns on the table of contents — pick a language and/or a genre to narrow the list (the two combine), „Reset" to clear both. At least one Sprache and one Genre tag are **required**: the build aborts on a song missing either. Tags are free text, so pick a vocabulary and keep it consistent (e.g. `Deutsch`, `Englisch`, `Mundart`, `Pop`, `Rock`, `Mantra`).

Nothing but blank lines may sit between the H1 and the first H2 — a capo note or any other aside goes into the `## Infos über das Lied` list instead (e.g. `- Capo: 3. Bund`); the build aborts otherwise.

## Live sync (multiplex)

The song book uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) so everyone in the room can follow along on their own device — song by song, led by the evening's host or by a volunteer.

Each evening is a **session** of its own. Whoever leads it taps 📡 › 🔑 „Als Gastgeber anmelden" and enters the password: that opens a new session. The others join by scanning its QR code (📡 › 🔗). Anyone already in the session can show that code too, so a neighbour can let a latecomer in. Each device then keeps the session in its own storage — reloading, a new tab or the song book reopened from the home screen stay in it — until the host ends it (🏁), a guest leaves it (🚪), or nothing has been heard of it for 12 hours. A device that never scanned a code is in no session, and nobody's evening ever moves its screen; two evenings at the same time never touch each other.

| Button | Position | Function |
|--------|----------|----------|
| 📖 | Top left | Jump to the table of contents (hidden while a live-scroll session locks your navigation) |
| ↕️ | Top right | Full screen, and back |
| 📡 | Bottom left | Live scrolling: a badge shows your connection/role at a glance; tap for the details, the login, 🚀 and 🔗 |
| ⚙️ | Bottom right | Settings — theme, chord visibility |

In the 📡 dialog:

| Button | Function |
|--------|----------|
| 🔑 | „Als Gastgeber anmelden" (asks for the password once per device), or, in a session, „Gastgeber übernehmen" |
| 🚀 | Host only: start live scrolling on the current song (songs only), or end it |
| 🔗 | In a session: show its QR code — scan to join |
| 🚪 | Guests: „Session verlassen" — this device leaves the session |
| 🏁 | Host only: „Session beenden" — everyone leaves the session |

Navigate to a song, then tap 📡 › 🚀 and choose **„Ich selber möchte scrollen"** to scroll it yourself, or **„Ein Gast soll scrollen"** to let someone in the audience take over. In guest mode everyone in the session is asked whether they want to scroll; the first to accept leads, and the rest follow. Whoever scrolls can only move up and down within that song.

While a song is live-scrolled, followers are held on the scroller's slide — their own navigation is off. The host and the scroller repeat themselves every two seconds, so whoever opens the song book late, or comes back from a dead spot, catches up by itself. Tap 📡 › 🚀 „Live-Scrollen beenden" to end it: everyone lands on the table of contents, is told they can navigate freely again, and a guest who scrolled is thanked.

As host, tick in the table of contents which Gastgeber are here tonight („Anwesend"): every list in the session then shows only the songs that can be played. Guests see the host's choice but cannot change it; Sprache and Genre stay theirs to filter.

There is one host at a time. Another device in the session can take the role over with 📡 › 🔑 „Gastgeber übernehmen" (and the password) — no need for the old host to hand anything on, which a phone with a flat battery couldn't. The old host stays in the session as a participant, and a song being live-scrolled carries on, its scroller included.

The badge on 📡 shows at a glance who's driving — a filled dot for you, a ring while you follow someone else, amber while waiting for a guest, a strike through it if the connection drops — and a tap opens a dialog spelling it out in words: „Du scrollst live", „Warte auf Gast …", „Gast scrollt", „Du scrollst für alle", „Folgt", „Du bist Gastgeber", „Kein Live-Scrollen aktiv", „Keine Session" or „Keine Verbindung".

Every role survives a reload: the host stays host, and whoever scrolls or follows is back in place at once.

Default password: `guitar`. Change it with:

```bash
MASTER_PASSWORD=yourpassword ./build
```

The build carries no multiplex credentials. The host's browser generates each session's secret when it logs in, and every device derives the relay channel from it (`sha256(secret)`, `style/sha256.js`) — the relay only checks that the two match.
