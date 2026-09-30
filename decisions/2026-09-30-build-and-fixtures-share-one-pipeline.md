## 2026-09-30 — The build and the spec fixtures share one pipeline

**Context:** `spec/support/fixture_builder.rb` copied the build's post-processing line by line, and `spec/integration/build_output_spec.rb` kept a third copy of the front matter. The copies had drifted: the fixtures' plugin-script removal matched a path they do not use, so every browser spec loaded three 404s; the all-songs spec broke the moment the front matter gained `lang`.

**Decision:** Front matter, Pandoc call and post-processing live in `lib/build_helpers.rb`; the build, the fixtures and the all-songs spec call them. What differs is a parameter: the path to `style/` and the multiplex config.

**Reasoning:** Specs that test a copy pass while the song book breaks. The refactor was checked by building before and after: `index.html`, `print.html` and `all-songs.md` came out byte-identical.
