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

`spec/support/fixture_builder.rb` builds `spec/fixtures/index.html` and `print.html` from the songs in `spec/fixtures/songs/`; both are committed. The browser specs serve them with WEBrick on `127.0.0.1` and a port the OS picks (`spec/support/file_server.rb`), so a second checkout's run does not collide with it.

**The specs never touch the live multiplex channel.** `spec/support/multiplex_server.rb` runs `multiplex-server/` — the official reveal-multiplex package, the same software the public Railway server runs, pinned by commit — on `127.0.0.1:18889` (`localhost.js` keeps it off the LAN) for the whole run. The fixture points at it with a fixed test pair (`sha256(secret) == socketId`, which is all the server checks). Before, the fixture carried `multiplex-token.json`, so the „live sync" spec became master on the channel songs.josh.ch listens to, and moved anyone who had it open at the time. Port and token are fixed rather than fresh per run so that the committed fixture stays the same from run to run. They refuse to start while port 18889 is taken (a multiplex server left over from a manual test, say): their own would die on `EADDRINUSE` while the other one answered the readiness check, and the specs would broadcast into it.

The only request that still leaves the machine is the night theme's Google Fonts `@import`; the slide-zoom expectations are measured with those fonts.

## Vendored reveal.js

`style/revealjs/` holds reveal.js **6.0.2** — only the five files the pages load (`dist/reveal.js`, `reveal.css`, `reset.css`, `theme/night.css`, `theme/serif.css`) plus its `LICENSE`. Everything under `style/` is deployed, so the rest of the release (tests, demo, other themes, `package-lock.json`) stays out. The paths match Pandoc's `revealjs-url`, which is why the `dist/` folder is kept.

To upgrade, copy those five files from `dist/` at the release's tag in the Git repository (`https://raw.githubusercontent.com/hakimel/reveal.js/<tag>/dist/…`), rebuild and run the specs. Pandoc's template also loads the notes, search and zoom plugins from their reveal.js 5 paths; the song book uses none of them, and `build` removes those script tags.

6.0.2 is the minimum: it makes every slide but the current one `inert` ([hakimel/reveal.js#1587](https://github.com/hakimel/reveal.js/issues/1587)). With 6.0.1, `Tab` on the Introduction reached the table of contents' links, which reveal.js keeps rendered next door but invisible — 35 of 40 presses landed there.

`style/qrcodejs/` holds qrcodejs 1.0.0 (the 🔗 dialog's QR code) with its `LICENSE`, served from the song book itself rather than jsDelivr.

## Keyboard and dialogs

**The two overlays are native `<dialog>`s** (🚀's password prompt and 🔗's QR code, in `style/body-controls.html`), opened with `showModal()`: the page behind is inert, Esc closes, and focus returns to the button that opened them. The QR dialog focuses its title (`tabindex="-1"`, no ring), so a screenreader starts there and a phone shows no keyboard; the password dialog focuses its field. Two things `showModal()` leaves to us: Reveal listens for keys on the document, where they still arrive from inside a dialog — so each dialog stops `keydown`/`keypress` from propagating, or the arrow keys would page the deck behind it and Esc would open Reveal's overview — and a click on the backdrop lands on the `<dialog>` itself, which closes it.

**Space on a focused button presses that button, and only that** (`keyboardCondition`, set with `Reveal.configure` on load): Reveal used to turn the page as well, so Space after 🌞 switched the theme back and moved on. The exception is a focus nobody can see: a mouse click leaves the button focused without a ring, and there Space blurs it and turns the page, as the one clicking expects. Whether the ring shows is read on `focusin`, because Chrome turns `:focus-visible` on as soon as any key is pressed.

## Multiplex (live sync)

The presentation uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) via `multiplex.up.railway.app` so that audience members can follow the presenter's slides in real time on their own devices.

The code is the second `<script>` in `style/body-controls.html`; the server is a pure relay (one event, `multiplex-statechanged`, forwarded to everyone but the sender when `sha256(secret) == socketId`, no storage).

- **Master** (🚀, top right): click → enter the password → your slide changes are broadcast to all clients; ❌ on 🚀 while active, click again to stop. The role is kept per tab (`sessionStorage` `multiplex-master`, holding the claim below), so a master that reloads — or whose tab iOS discarded — leads again without the password.
- **One master leads: whoever took over last.** The relay stops nobody from sending, and the password ships in the page, so the tabs agree on a rule instead. Every message carries `claim`, the time its sender took over, and `from`, an id per page load. A master that hears a higher claim steps down and becomes a client; a takeover claims at least one above every claim it heard, so a device whose clock runs behind still wins. An equal claim is a duplicated tab (it inherited the role): between masters, the higher `from` stays. A client takes an equal claim as the same leader reloaded under a new id, and ignores a lower claim until the leader has been silent for `LEADER_SILENCE_MS` (65 s — a tab in the background for a while is woken only once a minute).
- **Heartbeat:** the master repeats its state every 2 s (`HEARTBEAT_MS`; the specs shorten it through `window.MULTIPLEX.heartbeat`) and again right after a reconnect. That is how a client that opens the page mid-session, or comes back from a dead spot or a locked screen, catches up — the relay cannot hand out a last state. Repeats are only sent while connected (socket.io would queue them all and replay them at once), and a client drops a repeat that matches where it already is.
- **Client** (default): follows the master. **Following is the client's own choice**, per tab (`sessionStorage`, so a reload or iOS discarding the tab keeps it): 👣 „Browse freely" switches it off and on, and switching it back on jumps to the master's last state straight away.
- **Paging on one's own device switches to browsing freely.** Otherwise the next repeat would snap the page back within two seconds — the reason a heartbeat was once rejected here. Reveal events the master caused (`applyingRemote`, set around `Reveal.setState`) don't count.
- **QR code** (🔗, top right): shows a QR code of the current URL so new people can join.

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
