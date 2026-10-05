require 'nokogiri'
require 'json'
require 'open3'
require 'digest'
require 'securerandom'

module BuildHelpers
  module_function

  CHORD_REGEX = /\[([A-Z][^\]]*)\](?!\()/
  STYLE_DIR   = File.expand_path('../style', __dir__)

  # A self-consistent multiplex pair generated offline: the relay only verifies
  # sha256(secret) == socketId, so there is no need to fetch one from it. Used by
  # the `multiplex:token` rake task; CI/deploy generate the pair inline instead.
  def generate_multiplex_token
    secret = SecureRandom.hex(16)
    { 'socketId' => Digest::SHA256.hexdigest(secret), 'secret' => secret }
  end

  FRONTMATTER = <<~MD
    ---
    title:  Lieblings-Songs 🔥🎶🌛
    author: 😊 Josua & Monika ❤️
    lang:   de-CH
    ---
  MD

  def validate_song!(path, content)
    name = File.basename(path)
    errors = []

    errors << "must be valid UTF-8"               unless content.valid_encoding?
    errors << "must not have Windows line endings" if content.include?("\r\n")

    h1s = content.lines.select { |l| l.start_with?('# ') }
    errors << "must have exactly one H1 (found #{h1s.size})" unless h1s.size == 1

    h2s = content.lines.select { |l| l.start_with?('## ') }
    errors << "must have at least one H2 section (found #{h2s.size})" if h2s.empty?

    if h2s.any?
      title, = song_sections(content)
      stray = title.drop(1).reject { |l| l.strip.empty? }
      errors << "has content between the H1 and the first H2 — move it into \"#{ABOUT_HEADING}\": #{stray.map(&:strip).inspect}" unless stray.empty?
    end

    opens, closes = content.count('['), content.count(']')
    errors << "has mismatched brackets (#{opens} [ vs #{closes} ])" unless opens == closes

    bad_chords = content.scan(/\[([^\]]+)\](?!\()/).flatten
      .select { |c| c.match?(/^[A-Z]/) && c.include?(' ') }
    errors << "has chord names with spaces: #{bad_chords.inspect}" unless bad_chords.empty?

    by_category = song_tags(content).group_by { |(cat, _)| cat }
    errors << "is missing a Sprache tag in its \"#{ABOUT_HEADING}\" section" if (by_category['Sprache'] || []).empty?
    errors << "is missing a Genre tag in its \"#{ABOUT_HEADING}\" section"   if (by_category['Genre']   || []).empty?

    return if errors.empty?
    abort "#{name}: #{errors.join('; ')}"
  end

  def transform_chords(text)
    text.gsub(CHORD_REGEX) { "`#{$1}`{.#{$1[0].downcase}}" }
  end

  # The heading every song opens on: its Sprache/Genre tags and resource links,
  # authored directly in this shape in the source file (see song file format
  # in CLAUDE.md) rather than assembled from separate sections at build time.
  ABOUT_HEADING = 'Infos über das Lied'

  # A song's tags live as "- Sprache: X" / "- Genre: Y" / "- Gastgeber: X, Y"
  # list items in its ABOUT_HEADING section (one tag per list item; everything
  # else there — a Capo note, resource links — is not a tag and is skipped).
  # Returns [category, value] pairs in order, [] when there is no such
  # section. Sprache/Genre carry one value per list item; Gastgeber may name
  # several hosts on one line, comma-separated, and is split here into one
  # pair per name so every downstream consumer (grouping by category, the TOC
  # filter) sees the same flat shape regardless of category. The category is
  # exactly what was written, not inferred from a fixed vocabulary — so a
  # language, genre or host value this book hasn't seen before is still
  # classified correctly, and the About slide can't disagree with the filter
  # controls about what something is.
  def song_tags(content)
    lines = content.lines
    start = lines.index { |l| l.match?(/\A##\s+#{Regexp.escape(ABOUT_HEADING)}\s*\z/i) }
    return [] unless start

    lines[(start + 1)..].each_with_object([]) do |line, tags|
      break tags if line.start_with?('## ')
      m = line.match(/\A\s*[-*]\s+(Sprache|Genre|Gastgeber):\s*(.+?)\s*\z/i)
      next unless m

      category = m[1].downcase == 'sprache' ? 'Sprache' : (m[1].downcase == 'genre' ? 'Genre' : 'Gastgeber')
      if category == 'Gastgeber'
        m[2].split(',').each { |name| tags << [category, name.strip] }
      else
        tags << [category, m[2]]
      end
    end
  end

  # Splits a song's markdown into its leading title lines and an ordered list
  # of `## `-delimited sections ({name:, lines:}, lines including the heading
  # itself) — the shape merge_about_section needs to pull sections out by name
  # and reassemble the rest in their original order, and validate_song! needs
  # to check nothing but the H1 sits ahead of the first H2.
  def song_sections(content)
    # Without a trailing newline, the file's last line carries no "\n" of its own, so when
    # merge_about_section relocates that section its line-terminator goes missing too —
    # swallowing the blank line before whatever section follows.
    content += "\n" unless content.end_with?("\n")
    lines = content.lines
    first_h2 = lines.index { |l| l.start_with?('## ') } || lines.size
    title = lines[0...first_h2]

    sections = []
    lines[first_h2..].each do |line|
      if (m = line.match(/\A##\s+(.+?)\s*\z/))
        sections << { name: m[1], lines: [line] }
      else
        sections.last[:lines] << line
      end
    end
    [title, sections]
  end

  # Splices a song's `## Instructions` (alternate chord fingerings) into its
  # ABOUT_HEADING section — which already carries the song's tags and resource
  # links as authored in the source file — so every song opens on one slide
  # instead of scattering the same information across two.
  def merge_about_section(content)
    title, sections = song_sections(content)
    about        = sections.find { |s| s[:name] == ABOUT_HEADING }
    instructions = sections.find { |s| s[:name] == 'Instructions' }
    return content unless about

    rest = sections - [about, instructions].compact

    merged = about[:lines].dup
    if instructions
      body = instructions[:lines].drop(1).drop_while { |l| l.strip.empty? }
      merged << "\n" unless merged.last.strip.empty?
      merged += body
    end
    merged << "\n" unless merged.last.strip.empty? # a blank line before whatever section follows, or at EOF

    (title + merged + rest.flat_map { |s| s[:lines] }).join
  end

  def wrap_slide_content(html)
    doc = Nokogiri::HTML(html)
    doc.css('section[id], section[class]').each do |section|
      children = section.children.to_a
      wrapper = Nokogiri::XML::Node.new('div', doc)
      wrapper['class'] = 'slide-content'
      section.add_child(wrapper)
      children.each { |child| wrapper.add_child(child) }
    end
    doc.to_html
  end

  # Pandoc gives the deck's own title slide `id="title-slide"` and nothing
  # else. reveal.js's Location plugin builds the URL hash from the current
  # slide's id (getHash), so once that slide had been shown, reloading or
  # copying the URL never landed on a plain index.html again — it came back
  # as ".../#/title-slide". Swap the id for a class instead, so the slide
  # falls back to the bare "/" hash like any other id-less slide. A bare
  # "title-slide" class would collide with the one Pandoc already stamps on
  # every level-1 section (each song's own title slide), hence
  # "deck-title-slide". Run this before anything else in the pipeline, so
  # every later step (and every CSS/JS selector) only ever sees the class.
  # Idempotent: a no-op once the id is already gone.
  # See decisions/2026-10-05-title-slide-id-replaced-with-a-class.md.
  def rename_title_slide_id(html)
    html.sub('<section id="title-slide"', '<section class="deck-title-slide"')
  end

  # Each song's own title slide is a `section.level1 h1` (the top of its
  # `.stack`, distinct from the deck's own title-slide cover
  # (`section.deck-title-slide`), which carries no `level1` class and so
  # never matches here). Its H1 text is "Title - Artist"
  # once the source file uses that shape; split the artist out into its own
  # `<p class="song-artist">` right after the <h1> so CSS can size/colour it
  # apart from the title. A song with no " - " (an untitled-artist song, or
  # "Introduction") is left as a bare <h1>. Must run before wrap_slide_content,
  # so the new <p> still lands inside the same .slide-content div as the <h1>.
  def split_song_artist(html)
    doc = Nokogiri::HTML(html)
    doc.css('section.level1 > h1').each do |h1|
      title, sep, artist = h1.text.rpartition(' - ')
      next if sep.empty?

      h1.content = title
      p = Nokogiri::XML::Node.new('p', doc)
      p['class'] = 'song-artist'
      p.content = artist
      h1.add_next_sibling(p)
    end
    doc.to_html
  end

  # Carries the per-song tags (parsed from each ABOUT_HEADING section with song_tags,
  # one array of [category, value] pairs per song in the same order the TOC lists
  # them) into the TOC so toc-filter.js can filter it: a `data-sprache`/`data-genre`/
  # `data-gastgeber` attribute on each song's <li> and a <fieldset id="toc-filter">
  # with one <select> each for Sprache/Genre (single-choice, AND'd together),
  # a checkbox group for Gastgeber (any number of hosts can be checked at
  # once, OR'd together — a song usually has just one host, but showing songs
  # for *either* of two checked hosts is more useful than forcing one at a
  # time), and a Reset button at the top of #TOC. The first <li> is the
  # Introduction — it has no song behind it, so it is skipped. See
  # decisions/2026-10-05-gastgeber-filter-uses-checkboxes-not-a-select.md.
  def inject_toc_filter(html, tags:)
    doc = Nokogiri::HTML(html)
    toc = doc.at_css('section#TOC')
    return html unless toc

    list = toc.at_css('nav ul')
    return html unless list

    # The Introduction isn't a song and carries no tags — drop it from the
    # TOC entirely (it stays reachable as the deck's first slide) rather than
    # just excluding it from the filter, so `tags[i]` lines up with the
    # remaining <li>s by plain order.
    list.at_css('li')&.remove
    list.name = 'ol'

    list.css('li').each_with_index do |li, i|
      song = Array(tags[i]).map { |(cat, val)| [cat, val.to_s.strip] }.reject { |(_, val)| val.empty? }
      by_category = song.group_by { |(cat, _)| cat }
      li['data-sprache']   = by_category['Sprache'].map   { |(_, v)| v }.join(',') if by_category['Sprache']
      li['data-genre']     = by_category['Genre'].map     { |(_, v)| v }.join(',') if by_category['Genre']
      li['data-gastgeber'] = by_category['Gastgeber'].map { |(_, v)| v }.join(',') if by_category['Gastgeber']
    end

    all_pairs = tags.flat_map { |song| Array(song) }.map { |(cat, val)| [cat, val.to_s.strip] }.reject { |(_, val)| val.empty? }
    return doc.to_html if all_pairs.empty?

    sprachen   = all_pairs.select { |(cat, _)| cat == 'Sprache'   }.map { |(_, v)| v }.uniq.sort
    genres     = all_pairs.select { |(cat, _)| cat == 'Genre'     }.map { |(_, v)| v }.uniq.sort
    gastgeber  = all_pairs.select { |(cat, _)| cat == 'Gastgeber' }.map { |(_, v)| v }.uniq.sort

    fieldset = Nokogiri::XML::Node.new('fieldset', doc)
    fieldset['id'] = 'toc-filter'
    legend = Nokogiri::XML::Node.new('legend', doc)
    # The categories (Sprache/Genre/Gastgeber) next to their controls already
    # say what's being filtered; "Filter" itself only needs to reach a screen
    # reader.
    legend['class'] = 'visually-hidden'
    legend.content = 'Filter'
    fieldset.add_child(legend)
    fieldset.add_child(toc_filter_select(doc, id: 'toc-filter-sprache', label: 'Sprache', options: sprachen)) unless sprachen.empty?
    fieldset.add_child(toc_filter_select(doc, id: 'toc-filter-genre', label: 'Genre', options: genres)) unless genres.empty?
    fieldset.add_child(toc_filter_checkboxes(doc, id: 'toc-filter-gastgeber', label: 'Gastgeber', options: gastgeber)) unless gastgeber.empty?
    reset = Nokogiri::XML::Node.new('button', doc)
    reset['type'] = 'button'
    reset['id'] = 'toc-filter-reset'
    reset.content = 'Reset'
    fieldset.add_child(reset)

    toc.prepend_child(fieldset)

    empty_message = Nokogiri::XML::Node.new('p', doc)
    empty_message['id'] = 'toc-filter-empty'
    empty_message['class'] = 'toc-hidden'
    empty_message.content = 'Keine Ergebnisse, bitte Filter anpassen'
    list.add_next_sibling(empty_message)

    doc.to_html
  end

  def toc_filter_select(doc, id:, label:, options:)
    wrapper = Nokogiri::XML::Node.new('div', doc)
    wrapper['class'] = 'toc-filter-field'
    lbl = Nokogiri::XML::Node.new('label', doc)
    lbl['for'] = id
    lbl.content = label
    select = Nokogiri::XML::Node.new('select', doc)
    select['id'] = id
    all_option = Nokogiri::XML::Node.new('option', doc)
    all_option['value'] = ''
    all_option.content = 'Alle'
    select.add_child(all_option)
    options.each do |opt|
      option = Nokogiri::XML::Node.new('option', doc)
      option['value'] = opt
      option.content = opt
      select.add_child(option)
    end
    wrapper.add_child(lbl)
    wrapper.add_child(select)
    wrapper
  end

  # A checkbox group, for a category (Gastgeber) where more than one value can
  # be active at once — unlike toc_filter_select's single-choice <select>. A
  # plain `role="group"` <div> (not a nested <fieldset>/<legend>: Chrome and
  # Firefox both still render a <legend> as a caption on its own line even
  # inside a flex fieldset, which inflated the whole bar's height enough to
  # collide with the sticky-near-end-of-scroll edge case — see
  # decisions/2026-10-05-gastgeber-filter-uses-checkboxes-not-a-select.md)
  # carries the group semantics instead, labelled by a visible <span> playing
  # the same role Sprache/Genre's own <label> does. Each checkbox carries `id`
  # solely so its <label for> can target it; the value, not the id, is what
  # toc-filter.js reads.
  def toc_filter_checkboxes(doc, id:, label:, options:)
    group = Nokogiri::XML::Node.new('div', doc)
    group['class'] = 'toc-filter-field toc-filter-checkboxes'
    group['role'] = 'group'
    group['aria-label'] = label
    span = Nokogiri::XML::Node.new('span', doc)
    span['class'] = 'toc-filter-checkboxes-label'
    span.content = label
    group.add_child(span)
    options.each_with_index do |opt, i|
      checkbox_id = "#{id}-#{i}"
      lbl = Nokogiri::XML::Node.new('label', doc)
      lbl['for'] = checkbox_id
      checkbox = Nokogiri::XML::Node.new('input', doc)
      checkbox['type'] = 'checkbox'
      checkbox['id'] = checkbox_id
      checkbox['class'] = id
      checkbox['value'] = opt
      lbl.add_child(checkbox)
      lbl.add_child(Nokogiri::XML::Text.new(opt, doc))
      group.add_child(lbl)
    end
    group
  end

  # Everything below is shared by `build` and spec/support/fixture_builder.rb,
  # so the specs exercise the pipeline that builds the song book, not a copy.
  # `assets` is how the pages reach style/: "style/" beside index.html,
  # "/style/" for the fixtures served from spec/fixtures/.

  def songbook_markdown(song_files, introduction_path)
    songs = song_files.map { |file| transform_chords(merge_about_section(File.read(file, encoding: 'UTF-8'))) }
    [FRONTMATTER, File.read(introduction_path, encoding: 'UTF-8'), *songs].map(&:rstrip).join("\n\n") + "\n"
  end

  # Returns what Pandoc printed (warnings); raises if it failed.
  def pandoc!(markdown_path, output_path, theme:, revealjs_url:)
    output, status = Open3.capture2e(
      'pandoc', '-f', 'markdown+hard_line_breaks', '-t', 'revealjs', '-s', markdown_path, '-o', output_path,
      '--slide-level=2', '--syntax-highlighting=none', '--toc', '--toc-depth=1',
      '-V', "theme=#{theme}", '-V', 'progress=false', '-V', "revealjs-url=#{revealjs_url}", '-V', 'disableLayout=true'
    )
    raise "pandoc failed for #{output_path}:\n#{output}" unless status.success?
    output
  end

  def post_process_index(html, assets:, multiplex:, tags: [])
    html = rename_title_slide_id(html)
    html = html.sub('<style>', %(<link rel="stylesheet" href="#{assets}fonts/fonts.css">\n  <style>) + style_file('night.css') + style_file('shared.css'))
    html = without_pandoc_plugins(html)
    html = html.sub('keyboard: true,', "keyboard: { 83: null }, // 's' disabled (was: speaker notes)")
               .sub('controls: true,', 'controls: false,')
               .sub("display: 'block',", "display: 'flex',")
    # body-controls.html goes in *after* the Reveal-config rewrites above: it
    # configures Reveal too (a `keyboard: true` when a session ends), and a
    # sub that ran first would clobber that line instead of Pandoc's init.
    html = html.sub('<body>', "<body><script>window.MULTIPLEX=#{multiplex.to_json};</script>" + style_file('body-controls.html').strip)
    scripts = ["#{multiplex[:url]}/socket.io/socket.io.js", "#{assets}qrcodejs/qrcode.min.js", "#{assets}slide-zoom.js", "#{assets}chords.js", "#{assets}toc-filter.js"]
    html = html.sub('</body>', scripts.map { |src| %(  <script src="#{src}"></script>\n) }.join + '</body>')
    wrap_slide_content(inject_toc_filter(split_song_artist(html), tags: tags))
  end

  def post_process_print(html, assets:)
    html = html.sub('<style>', '<style>' + style_file('serif.css') + style_file('shared.css'))
    # ABOUT_HEADING carries tags, resource links and alternate fingerings — all
    # screen features, useless on paper (merge_about_section folds instructions
    # into this one section, so stripping it alone is enough). Pandoc slugifies
    # the heading text verbatim (lowercased, spaces to hyphens, "ü" kept as-is)
    # for the id, with a "-N" suffix to disambiguate it across songs.
    html = html.gsub(/<section id="infos-über-das-lied[-\d]*?" class="slide level2">.*?<\/section>/m, '')
    html = rename_title_slide_id(html)
    html = html.sub('<section class="deck-title-slide"', %(<section class="deck-title-slide" data-background-image="#{assets}background.jpg"))
    wrap_slide_content(split_song_artist(without_pandoc_plugins(html)))
  end

  def style_file(name)
    File.read(File.join(STYLE_DIR, name), encoding: 'UTF-8')
  end

  # Pandoc's template loads the notes, search and zoom plugins from their
  # reveal.js 5 paths; the song book uses none of them.
  def without_pandoc_plugins(html)
    html.gsub(%r{  <script src="[^"]*/plugin/(notes|search|zoom)/\1\.js"></script>\n}, '')
        .sub("plugins: [\n          RevealNotes,\n          RevealSearch,\n          RevealZoom\n        ]", 'plugins: []')
  end
end
