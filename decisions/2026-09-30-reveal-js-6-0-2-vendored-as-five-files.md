## 2026-09-30 — reveal.js 6.0.2, vendored as the five files the pages load

**Context:** `style/revealjs/` held the whole reveal.js repository (5.8 MB: tests, demo, every theme, `package-lock.json`), and `./build --deploy` uploads `style/` as a whole. Dependabot kept opening PRs for the npm dependencies of reveal.js's own build. With 6.0.1, `Tab` on the Introduction reached the table of contents' links: reveal.js keeps the neighbouring slides rendered but invisible, and in a headless run 35 of 40 presses landed there.

**Decision:** Upgrade to 6.0.2, which makes every slide but the current one `inert` ([hakimel/reveal.js#1587](https://github.com/hakimel/reveal.js/issues/1587)), and keep only `dist/reveal.js`, `reveal.css`, `reset.css`, `theme/night.css`, `theme/serif.css` and the `LICENSE`, copied from the release tag in the Git repository.

**Reasoning:** The `dist/` path is kept because it is what Pandoc's `revealjs-url` expects. `.reveal { overflow: clip }`, which Axipedia adds on top of the upgrade, was tried and dropped again: in the song book nothing scrolls the frame even with 6.0.1, because the table of contents is its own scroll container and absorbs the focus scrolling. A rule that fixes no observed problem is only something to explain later.
