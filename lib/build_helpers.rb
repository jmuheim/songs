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

    opens, closes = content.count('['), content.count(']')
    errors << "has mismatched brackets (#{opens} [ vs #{closes} ])" unless opens == closes

    bad_chords = content.scan(/\[([^\]]+)\](?!\()/).flatten
      .select { |c| c.match?(/^[A-Z]/) && c.include?(' ') }
    errors << "has chord names with spaces: #{bad_chords.inspect}" unless bad_chords.empty?

    return if errors.empty?
    abort "#{name}: #{errors.join('; ')}"
  end

  def transform_chords(text)
    text.gsub(CHORD_REGEX) { "`#{$1}`{.#{$1[0].downcase}}" }
  end

  # A song's tags live as a markdown list in its `## About` section (one tag per
  # list item). Returns the trimmed item texts in order, [] when there is no
  # About section. Prose in About is ignored, so the section can hold more later.
  def song_tags(content)
    lines = content.lines
    start = lines.index { |l| l.match?(/\A##\s+About\s*\z/i) }
    return [] unless start

    lines[(start + 1)..].each_with_object([]) do |line, tags|
      break tags if line.start_with?('## ')
      m = line.match(/\A\s*[-*]\s+(.+?)\s*\z/)
      tags << m[1] if m
    end
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

  # Carries the per-song tags (parsed from each `## About` section with song_tags,
  # one array per song in the same order the TOC lists them) into the TOC so
  # toc-filter.js can filter it: a `data-tags` attribute on each song's <li> and a
  # chip bar (one <button> per distinct tag, plus „Alle") at the top of #TOC. The
  # first <li> is the Introduction — it has no song behind it, so it is skipped.
  def inject_toc_filter(html, tags:)
    doc = Nokogiri::HTML(html)
    toc = doc.at_css('section#TOC')
    return html unless toc

    toc.css('nav li').drop(1).each_with_index do |li, i|
      song = Array(tags[i]).map { |t| t.to_s.strip }.reject(&:empty?)
      li['data-tags'] = song.join(',') unless song.empty?
    end

    all_tags = tags.flatten.map { |t| t.to_s.strip }.reject(&:empty?).uniq.sort
    return doc.to_html if all_tags.empty?

    bar = Nokogiri::XML::Node.new('div', doc)
    bar['id'] = 'toc-filter'
    bar['role'] = 'group'
    bar['aria-label'] = 'Nach Tag filtern'
    bar.add_child(toc_tag_button(doc, label: 'Alle', extra_class: ' toc-tag-all', pressed: true))
    all_tags.each do |tag|
      bar.add_child(toc_tag_button(doc, label: tag, data_tag: tag, pressed: false))
    end
    toc.prepend_child(bar)
    doc.to_html
  end

  def toc_tag_button(doc, label:, pressed:, extra_class: '', data_tag: nil)
    btn = Nokogiri::XML::Node.new('button', doc)
    btn['type'] = 'button'
    btn['class'] = "toc-tag#{extra_class}"
    btn['data-tag'] = data_tag if data_tag
    btn['aria-pressed'] = pressed ? 'true' : 'false'
    btn.content = label
    btn
  end

  # Everything below is shared by `build` and spec/support/fixture_builder.rb,
  # so the specs exercise the pipeline that builds the song book, not a copy.
  # `assets` is how the pages reach style/: "style/" beside index.html,
  # "/style/" for the fixtures served from spec/fixtures/.

  def songbook_markdown(song_files, introduction_path)
    songs = song_files.map { |file| transform_chords(File.read(file, encoding: 'UTF-8')) }
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
    # Resources (links) and About (tags) are screen features — useless on paper.
    html = html.gsub(/<section id="(?:resources|about)[-\d]*?" class="slide level2">.*?<\/section>/m, '')
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
