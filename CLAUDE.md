# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A guitar song book generator. Songs are written in Markdown with inline chord notation. A Ruby script compiles them into an interactive Reveal.js HTML slideshow (`index.html`) and a print-friendly version (`print.html`).

## Build command

```bash
./build           # Build index.html and print.html
./build --deploy  # HTML + deploy to songs.josh.ch
./dev             # Watch, rebuild, deploy, and live-reload on every change
```

Dependencies: Ruby 3.x, Pandoc (`brew install pandoc`), fswatch (`brew install fswatch`), browser-sync (`npm install -g browser-sync`).

> **Dev gotcha:** `./dev` passes `--no-ghost-mode` to browser-sync. Ghost mode (on by default) syncs clicks across all open tabs and interferes with the multiplex feature — it makes button presses appear to fire on all "clients" simultaneously during local testing.

## Song file format

Each song lives in `content/songs/<Title> (<Artist>).md`. Structure:

```markdown
# ❤️ Song Title (Artist Name)

## Section Name

Lyrics with [Chord] inline like this [Am] and here [G7].

## Resources

- [Song](https://youtube.com/...)
```

- **H1** = song title (one per file, shown as the slide title)
- **H2** = section (each becomes a sub-slide)
- **Chords** use `[ChordName]` inline in lyrics
- A `## Resources` section is automatically stripped from `print.html` (links are useless in print)
- `content/Introduction.md` is always prepended as the first slide

## Chord rendering pipeline

The Ruby script transforms `[Chord]` markers before passing to Pandoc:

```
[C] → `C`{.c}    (CSS class = lowercase first letter)
[Am] → `Am`{.a}
[G7] → `G7`{.g}
```

Pandoc renders these as `<code class="a">Am</code>` etc. CSS in `style/shared.css` assigns a distinct color per chord letter (A=red, B=gray, C=blue, D=green, E=yellow, F=violet, G=brown).

The regex only matches `[Word]` not followed by `(` — so standard Markdown links `[text](url)` are left untouched.

## Output files

- `all-songs.md` — intermediate concatenated Markdown (committed, regenerated on each build)
- `index.html` — interactive night-themed Reveal.js presentation (committed)
- `print.html` — serif-themed version for printing (committed). Open it as `print.html?print-pdf` in Chrome and print: reveal.js then lays out every slide as a page of its own

## Tests

```bash
npm install --prefix multiplex-server   # once; needs Node.js >= 18
bundle exec rspec
```

`spec/support/fixture_builder.rb` builds `spec/fixtures/index.html` and `print.html` from the songs in `spec/fixtures/songs/`; both are committed. The browser specs serve them with WEBrick on port 18888 (`spec/support/file_server.rb`).

**The specs never touch the live multiplex channel.** `spec/support/multiplex_server.rb` runs `multiplex-server/` — the official reveal-multiplex package, the same software the public Railway server runs, pinned by commit — on `127.0.0.1:18889` (`localhost.js` keeps it off the LAN) for the whole run. The fixture points at it with a fixed test pair (`sha256(secret) == socketId`, which is all the server checks). Before, the fixture carried `multiplex-token.json`, so the „live sync" spec became master on the channel songs.josh.ch listens to, and moved anyone who had it open at the time. Port and token are fixed rather than fresh per run so that the committed fixture stays the same from run to run.

The only request that still leaves the machine is the night theme's Google Fonts `@import`; the slide-zoom expectations are measured with those fonts.

## Vendored reveal.js

`style/revealjs/` holds reveal.js **6.0.2** — only the five files the pages load (`dist/reveal.js`, `reveal.css`, `reset.css`, `theme/night.css`, `theme/serif.css`) plus its `LICENSE`. Everything under `style/` is deployed, so the rest of the release (tests, demo, other themes, `package-lock.json`) stays out. The paths match Pandoc's `revealjs-url`, which is why the `dist/` folder is kept.

To upgrade, copy those five files from `dist/` at the release's tag in the Git repository (`https://raw.githubusercontent.com/hakimel/reveal.js/<tag>/dist/…`), rebuild and run the specs. Pandoc's template also loads the notes, search and zoom plugins from their reveal.js 5 paths; the song book uses none of them, and `build` removes those script tags.

6.0.2 is the minimum: it makes every slide but the current one `inert` ([hakimel/reveal.js#1587](https://github.com/hakimel/reveal.js/issues/1587)). With 6.0.1, `Tab` on the Introduction reached the table of contents' links, which reveal.js keeps rendered next door but invisible — 35 of 40 presses landed there.

`style/qrcodejs/` holds qrcodejs 1.0.0 (the 🔗 dialog's QR code) with its `LICENSE`, served from the song book itself rather than jsDelivr.

## Multiplex (live sync)

The presentation uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) via `multiplex.up.railway.app` so that audience members can follow the presenter's slides in real time on their own devices.

- **Client** (default): anyone who opens the URL receives slide updates automatically.
- **Master** (🎤 button, bottom-right): click → enter the password → your slide changes are broadcast to all clients. The button turns 🎙️ when active.
- **QR code** (📱 button, above 🎤): shows a QR code of the current URL so new people can join.

### Known limitation

New clients who join mid-session are not synced to the current slide — they only receive updates on the next master navigation event. The workaround is for the master to tap next then back to re-broadcast. A heartbeat was considered but rejected because it would snap clients back to the master slide every N seconds, breaking independent browsing.

The proper fix is a self-hosted multiplex server that caches `lastState` and emits it to each new socket on `connection`. The public server at `multiplex.up.railway.app` is a pure relay (one event: `multiplex-statechanged`, no storage) and cannot be modified.

### Token (`multiplex-token.json`)

The `socketId` / `secret` pair is fetched once from the server and cached in `multiplex-token.json` (committed). All viewers share this session. Delete the file and rebuild to start a fresh session.

### Password

Default password: `guitar`. Override with the `MASTER_PASSWORD` env var at build time:

```bash
MASTER_PASSWORD=mypassword ./build
```

The password is embedded in the generated HTML (visible in source). This is intentional — the goal is only to prevent accidental master takeover, not real security.

## Legacy songs

`content/legacy-songs/` holds songs removed from the active set. They are not included in the build.
