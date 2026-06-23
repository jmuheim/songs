require 'json'
require 'fileutils'
require_relative '../../lib/build_helpers'

module FixtureBuilder
  extend BuildHelpers

  ROOT          = File.expand_path('../..', __dir__)
  FIXTURE_DIR   = File.join(ROOT, 'spec', 'fixtures')
  SONGS_DIR     = File.join(FIXTURE_DIR, 'songs')
  OUTPUT        = File.join(FIXTURE_DIR, 'index.html')
  PRINT_OUTPUT  = File.join(FIXTURE_DIR, 'print.html')
  URL_PATH      = '/spec/fixtures/index.html'
  PRINT_URL_PATH = '/spec/fixtures/print.html'

  MULTIPLEX_URL = 'https://multiplex.up.railway.app'

  def self.build!
    return if @built

    song_files = Dir[File.join(SONGS_DIR, '*.md')].sort
    raise "No fixture songs found in #{SONGS_DIR}" if song_files.empty?

    frontmatter = <<~MD
      ---
      title:  Lieblings-Songs 🔥🎶🌛
      author: 😊 Josua & Monika ❤️
      ---
    MD

    songs_md     = song_files.map { |f| transform_chords(File.read(f, encoding: 'UTF-8')) }
    introduction = File.read(File.join(ROOT, 'content', 'Introduction.md'), encoding: 'UTF-8')
    parts        = [frontmatter, introduction, *songs_md].map(&:rstrip)
    all_songs_md = parts.join("\n\n") + "\n"

    Dir.mktmpdir('fixture-build-') do |tmpdir|
      md_path         = File.join(tmpdir, 'all-songs.md')
      index_html_path = File.join(tmpdir, 'index.html')
      print_html_path = File.join(tmpdir, 'print.html')
      File.write(md_path, all_songs_md, encoding: 'UTF-8')

      pandoc_base = [
        'pandoc', '-f', 'markdown+hard_line_breaks', '-t', 'revealjs', '-s',
        md_path, '--slide-level=2', '--syntax-highlighting=none',
        '--toc', '--toc-depth=1', '-V', 'progress=false',
        '-V', 'revealjs-url=/style/revealjs', '-V', 'disableLayout=true'
      ]

      # Use absolute revealjs-url so the HTML works when served from /spec/fixtures/
      raise 'pandoc failed (index)' unless system(
        *pandoc_base, '-o', index_html_path, '-V', 'theme=night',
        out: File::NULL, err: File::NULL
      )
      raise 'pandoc failed (print)' unless system(
        *pandoc_base, '-o', print_html_path, '-V', 'theme=serif',
        out: File::NULL, err: File::NULL
      )

      html = File.read(index_html_path, encoding: 'UTF-8')

      token           = JSON.parse(File.read(File.join(ROOT, 'multiplex-token.json')))
      multiplex_json  = { url: MULTIPLEX_URL, socketId: token['socketId'],
                          secret: token['secret'], password: 'guitar' }.to_json
      body_controls   = File.read(File.join(ROOT, 'style', 'body-controls.html'), encoding: 'UTF-8').strip

      html.sub!('<body>', "<body><script>window.MULTIPLEX=#{multiplex_json};</script>#{body_controls}")
      html.sub!('<style>', "<style>#{File.read(File.join(ROOT, 'style', 'night.css'), encoding: 'UTF-8')}#{File.read(File.join(ROOT, 'style', 'shared.css'), encoding: 'UTF-8')}")
      html.gsub!(%r{  <script src="./style/revealjs/plugin/(notes|search|zoom)/\1\.js"></script>\n}, '')
      html.sub!("plugins: [\n          RevealNotes,\n          RevealSearch,\n          RevealZoom\n        ]", 'plugins: []')
      html.sub!('keyboard: true,',  "keyboard: { 83: null }, // 's' disabled (was: speaker notes)")
      html.sub!('controls: true,',  'controls: false,')
      html.sub!("display: 'block',", "display: 'flex',")
      html.sub!(
        '</body>',
        "  <script src=\"#{MULTIPLEX_URL}/socket.io/socket.io.js\"></script>\n" \
        "  <script src=\"https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js\"></script>\n" \
        "  <script src=\"/style/slide-zoom.js\"></script>\n</body>"
      )
      html = wrap_slide_content(html)

      print_html = File.read(print_html_path, encoding: 'UTF-8')
      print_html.sub!('<style>', "<style>#{File.read(File.join(ROOT, 'style', 'serif.css'), encoding: 'UTF-8')}#{File.read(File.join(ROOT, 'style', 'shared.css'), encoding: 'UTF-8')}")
      print_html.gsub!(/<section id="resources[-\d]*?" class="slide level2">.*?<\/section>/m, '')
      print_html.sub!('<section id="title-slide"', '<section id="title-slide" data-background-image="/style/background.jpg"')
      print_html.gsub!(%r{  <script src="./style/revealjs/plugin/(notes|search|zoom)/\1\.js"></script>\n}, '')
      print_html.sub!("plugins: [\n          RevealNotes,\n          RevealSearch,\n          RevealZoom\n        ]", 'plugins: []')
      print_html = wrap_slide_content(print_html)

      FileUtils.mkdir_p(FIXTURE_DIR)
      File.write(OUTPUT, html, encoding: 'UTF-8')
      File.write(PRINT_OUTPUT, print_html, encoding: 'UTF-8')
    end

    @built = true
  end
end
