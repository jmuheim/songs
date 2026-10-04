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

  # A song's tags live as "- Sprache: X" / "- Genre: Y" list items in its
  # ABOUT_HEADING section (one tag per list item; everything else there — a
  # Capo note, resource links — is not a tag and is skipped). Returns
  # [category, value] pairs in order, [] when there is no such section. The
  # category is exactly what was written, not inferred from a fixed
  # vocabulary — so a language or genre value this book hasn't seen before
  # is still classified correctly, and the About slide can't disagree with
  # the filter dropdowns about what something is.
  def song_tags(content)
    lines = content.lines
    start = lines.index { |l| l.match?(/\A##\s+#{Regexp.escape(ABOUT_HEADING)}\s*\z/i) }
    return [] unless start

    lines[(start + 1)..].each_with_object([]) do |line, tags|
      break tags if line.start_with?('## ')
      m = line.match(/\A\s*[-*]\s+(Sprache|Genre):\s*(.+?)\s*\z/i)
      tags << [m[1].downcase == 'sprache' ? 'Sprache' : 'Genre', m[2]] if m
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

  # Carries the per-song tags (parsed from each ABOUT_HEADING section with song_tags,
  # one array of [category, value] pairs per song in the same order the TOC lists
  # them) into the TOC so toc-filter.js can filter it: a `data-sprache`/`data-genre`
  # attribute on each song's <li> and a <fieldset id="toc-filter"> with one
  # <select> per category plus a Reset button at the top of #TOC. The first
  # <li> is the Introduction — it has no song behind it, so it is skipped.
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
      li['data-sprache'] = by_category['Sprache'].map { |(_, v)| v }.join(',') if by_category['Sprache']
      li['data-genre']   = by_category['Genre'].map   { |(_, v)| v }.join(',') if by_category['Genre']
    end

    all_pairs = tags.flat_map { |song| Array(song) }.map { |(cat, val)| [cat, val.to_s.strip] }.reject { |(_, val)| val.empty? }
    return doc.to_html if all_pairs.empty?

    sprachen = all_pairs.select { |(cat, _)| cat == 'Sprache' }.map { |(_, v)| v }.uniq.sort
    genres   = all_pairs.select { |(cat, _)| cat == 'Genre'   }.map { |(_, v)| v }.uniq.sort

    fieldset = Nokogiri::XML::Node.new('fieldset', doc)
    fieldset['id'] = 'toc-filter'
    legend = Nokogiri::XML::Node.new('legend', doc)
    # The categories (Sprache/Genre) next to their selects already say what's
    # being filtered; "Filter" itself only needs to reach a screen reader.
    legend['class'] = 'visually-hidden'
    legend.content = 'Filter'
    fieldset.add_child(legend)
    fieldset.add_child(toc_filter_select(doc, id: 'toc-filter-sprache', label: 'Sprache', options: sprachen)) unless sprachen.empty?
    fieldset.add_child(toc_filter_select(doc, id: 'toc-filter-genre', label: 'Genre', options: genres)) unless genres.empty?
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
    wrap_slide_content(inject_toc_filter(html, tags: tags))
  end

  def post_process_print(html, assets:)
    html = html.sub('<style>', '<style>' + style_file('serif.css') + style_file('shared.css'))
    # ABOUT_HEADING carries tags, resource links and alternate fingerings — all
    # screen features, useless on paper (merge_about_section folds instructions
    # into this one section, so stripping it alone is enough). Pandoc slugifies
    # the heading text verbatim (lowercased, spaces to hyphens, "ü" kept as-is)
    # for the id, with a "-N" suffix to disambiguate it across songs.
    html = html.gsub(/<section id="infos-über-das-lied[-\d]*?" class="slide level2">.*?<\/section>/m, '')
    html = html.sub('<section id="title-slide"', %(<section id="title-slide" data-background-image="#{assets}background.jpg"))
    wrap_slide_content(without_pandoc_plugins(html))
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
