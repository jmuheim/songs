# My Songs

A collection of songs I perform on guitar. Written in Markdown with inline chord notation, compiled into an interactive Reveal.js slideshow and a print-friendly version.

A live version is at [songs.josh.ch](https://songs.josh.ch).

## Features

- Swipe left/right to change songs, up/down to navigate song sections
- Colour-coded chords (each root letter gets its own colour)
- Toggle chord visibility (🎹 button)
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
bundle exec rake multiplex:token   # once per clone: create local multiplex credentials
./build                            # Build index.html and print.html
./build --deploy                   # HTML + deploy to songs.josh.ch (manual fallback)
./dev                              # Watch, rebuild, and live-reload on every change (local only)
```

`build` refuses to run without multiplex credentials; `rake multiplex:token` writes a gitignored `multiplex-token.json` for local use (see [Live sync](#live-sync-multiplex)). The usual way to publish is **not** `--deploy`: a push to `master` deploys to songs.josh.ch from CI once the tests pass (`.github/workflows/test.yml`).

> Song files contain non-ASCII characters; `build` sets `LANG` and the UTF-8 encoding itself, so no `LANG=…` prefix is needed.

> **Dev note:** `./dev` runs browser-sync with `--no-ghost-mode`. Ghost mode (enabled by default) syncs clicks across all open tabs, which interferes with the multiplex feature — every button press would appear to fire on all "clients" simultaneously during local testing.

## Tests

```bash
npm install --prefix multiplex-server   # once
bundle exec rspec
```

The browser specs run their own multiplex server on `127.0.0.1:18889`, so a spec that becomes presenter never moves anyone who has songs.josh.ch open.

GitHub Actions runs the whole suite on every push and pull request (`.github/workflows/test.yml`).

## Adding songs

Add a Markdown file to `content/songs/` following the naming convention `Title (Artist).md`. Chords go inline as `[Am]`, `[G7]`, etc.

To tag a song, add an `## About` section at the top with one tag per list item:

```markdown
# Kiss the Earth (Ajeet)

## About

- Englisch
- Mantra

## Verse 1

...
```

The tags show on a short „About" slide after the song title and drive the filter chips on the table of contents — pick several to see songs matching **any** of them, „Alle" to clear. Tagging is optional: an untagged song just shows under „Alle". Tags are free text, so pick a vocabulary and keep it consistent (e.g. `Deutsch`, `Englisch`, `Mundart`, `Pop`, `Rock`, `Mantra`).

## Live sync (multiplex)

The song book uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) so everyone in the room can follow along on their own device — song by song, led by the presenter or by a volunteer.

| Button | Position | Function |
|--------|----------|----------|
| 🔗 | Top right | Show QR code — scan to open the song book |
| 🚀 | Top right | Start a live-scroll session on the current song (asks for the password once); ❌ while active, tap again to end it |

Navigate to a song, then tap 🚀 and choose **„Ich selber möchte scrollen"** to scroll it yourself, or **„Ein Gast soll scrollen"** to let someone in the audience take over. In guest mode everyone with the page open is asked whether they want to scroll; the first to accept leads, and the rest follow. Whoever scrolls can only move up and down within that song.

While a session runs, followers are held on the scroller's slide — their own navigation is off. The scroller repeats its position every two seconds, so whoever opens the song book late, or comes back from a dead spot, catches up by itself. Tap ❌ on 🚀 to end the session: everyone is told they can navigate freely again, and a guest who scrolled is thanked.

A short line under the buttons says what is going on: „Du scrollst live", „Warte auf Gast …", „Gast scrollt", „Du scrollst für alle", „Folgt", or „Keine Verbindung".

The presenter's tab stays presenter — and keeps its live session — when it reloads.

Default password: `guitar`. Change it with:

```bash
MASTER_PASSWORD=yourpassword ./build
```

The `socketId`/`secret` pair the sync uses is generated offline (the relay only checks `sha256(secret) == socketId`) — never fetched. Create your local pair once with `bundle exec rake multiplex:token`; it lands in a gitignored `multiplex-token.json`, so your local builds get their own session and never share the live songs.josh.ch channel. The CI deploy generates a fresh pair per run.
