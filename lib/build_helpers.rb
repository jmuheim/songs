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

  def post_process_index(html, assets:, multiplex:)
    html = html.sub('<style>', %(<link rel="stylesheet" href="#{assets}fonts/fonts.css">\n  <style>) + style_file('night.css') + style_file('shared.css'))
    html = without_pandoc_plugins(html)
    html = html.sub('keyboard: true,', "keyboard: { 83: null }, // 's' disabled (was: speaker notes)")
               .sub('controls: true,', 'controls: false,')
               .sub("display: 'block',", "display: 'flex',")
    # body-controls.html goes in *after* the Reveal-config rewrites above: it
    # configures Reveal too (a `keyboard: true` when a session ends), and a
    # sub that ran first would clobber that line instead of Pandoc's init.
    html = html.sub('<body>', "<body><script>window.MULTIPLEX=#{multiplex.to_json};</script>" + style_file('body-controls.html').strip)
    scripts = ["#{multiplex[:url]}/socket.io/socket.io.js", "#{assets}qrcodejs/qrcode.min.js", "#{assets}slide-zoom.js", "#{assets}chords.js"]
    html = html.sub('</body>', scripts.map { |src| %(  <script src="#{src}"></script>\n) }.join + '</body>')
    wrap_slide_content(html)
  end

  def post_process_print(html, assets:)
    html = html.sub('<style>', '<style>' + style_file('serif.css') + style_file('shared.css'))
    html = html.gsub(/<section id="resources[-\d]*?" class="slide level2">.*?<\/section>/m, '')
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
