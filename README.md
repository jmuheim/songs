# My Songs

A collection of songs I perform on guitar. Written in Markdown with inline chord notation, compiled into an interactive Reveal.js slideshow and a printable PDF.

A live version is at [josh.ch/songs](https://josh.ch/songs).

## Features

- Swipe left/right to change songs, up/down to navigate song sections
- Colour-coded chords (each root letter gets its own colour)
- Toggle chord visibility (🎹 button)
- **Live sync** — open the song book on your phone and follow along as the presenter advances slides (see below)
- Printable PDF version

## Installation

- [Ruby](https://www.ruby-lang.org/) 3.x
- [Pandoc](https://pandoc.org/): `brew install pandoc`
- [DeckTape](https://github.com/astefanutti/decktape) (PDF only): `npm install -g decktape`

## Build

```bash
LANG=en_US.UTF-8 ./build           # HTML only (fast)
LANG=en_US.UTF-8 ./build --pdf     # HTML + PDF (slow)
LANG=en_US.UTF-8 ./build --deploy  # HTML + deploy to josh.ch/songs
```

> `LANG=en_US.UTF-8` is required because song files contain non-ASCII characters.

## Adding songs

Add a Markdown file to `content/songs/` following the naming convention `Title (Artist).md`. Chords go inline as `[Am]`, `[G7]`, etc.

## Live sync (multiplex)

The song book uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) so everyone in the room can follow along on their own device.

| Button | Position | Function |
|--------|----------|----------|
| 📱 | Bottom-right | Show QR code — scan to open the song book |
| 🎤 | Bottom-right (below 📱) | Become the presenter (asks for password) |

Once you enter the password and become master (🎙️), your slide navigation is broadcast live to everyone who has the page open.

Default password: `guitar`. Change it with:

```bash
MASTER_PASSWORD=yourpassword LANG=en_US.UTF-8 ./build
```
