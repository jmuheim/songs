# My Songs

A collection of songs I perform on guitar. Written in Markdown with inline chord notation, compiled into an interactive Reveal.js slideshow and a print-friendly version.

A live version is at [songs.josh.ch](https://songs.josh.ch).

## Features

- Swipe left/right to change songs, up/down to navigate song sections
- Colour-coded chords (each root letter gets its own colour)
- Toggle chord visibility (🎹 button)
- **Live sync** — open the song book on your phone and follow along as the presenter advances slides (see below)
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
./build --deploy  # HTML + deploy to songs.josh.ch
./dev             # Watch, rebuild, and live-reload on every change
```

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

## Live sync (multiplex)

The song book uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) so everyone in the room can follow along on their own device.

| Button | Position | Function |
|--------|----------|----------|
| 🔗 | Top right | Show QR code — scan to open the song book |
| 👣 | Top right | Browse freely instead of following the presenter (❌ while browsing freely); tap again to jump back to the presenter's slide |
| 🚀 | Top right | Become the presenter (asks for password); tap again to stop |

Once you enter the password and become presenter (❌ on 🚀), your slide navigation is broadcast live to everyone who has the page open. The presenter also repeats the current slide every two seconds, so whoever opens the song book later, or comes back from a dead spot, catches up by itself.

A short line under the buttons says what is going on: whether you follow, browse freely, present yourself, or whether nobody is presenting right now. Browsing the overview (Esc) or pausing (B) as presenter stays on your own screen.

Paging on your own device switches you to browsing freely, so that the next repeat does not snap you back — 👣 brings you back to the presenter.

The presenter's tab stays presenter when it reloads. If someone else enters the password, they take over and the previous presenter becomes a listener.

Default password: `guitar`. Change it with:

```bash
MASTER_PASSWORD=yourpassword ./build
```
