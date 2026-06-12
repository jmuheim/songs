# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A guitar song book generator. Songs are written in Markdown with inline chord notation. A Ruby script compiles them into an interactive Reveal.js HTML slideshow (`index.html`) and a printable PDF-ready version (`print.html` / `print.pdf`).

## Build command

```bash
./build           # HTML only (fast)
./build --pdf     # HTML + PDF (slow)
./build --deploy  # HTML + deploy to songs.josh.ch
./dev             # Watch, rebuild, deploy, and live-reload on every change
```

Dependencies: Ruby 3.x, Pandoc (`brew install pandoc`), DeckTape (`npm install -g decktape`), fswatch (`brew install fswatch`), browser-sync (`npm install -g browser-sync`).

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
- `print.html` — serif-themed version for PDF printing (committed)
- `print.pdf` — generated PDF (committed)

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
