RSpec.describe 'HTML post-processing rules' do
  let(:base_html) do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><style>existing</style></head>
      <body>
        <section id="title-slide"><h1>Title</h1></section>
        <section class="level1">
          <section id="song" class="slide level2">
            <h2>Song</h2>
            <p><code class="a">Am</code> lyrics</p>
          </section>
          <section id="resources-1" class="slide level2">
            <h2>Resources</h2>
            <ul><li><a href="https://example.com">Link</a></li></ul>
          </section>
        </section>
        <script src="./style/revealjs/plugin/notes/notes.js"></script>
        <script src="./style/revealjs/plugin/search/search.js"></script>
        <script src="./style/revealjs/plugin/zoom/zoom.js"></script>
        plugins: [
          RevealNotes,
          RevealSearch,
          RevealZoom
        ]
        keyboard: true,
        controls: true,
        display: 'block',
      </body>
      </html>
    HTML
  end

  describe 'index.html post-processing' do
    subject(:processed) do
      html = base_html.dup
      html.sub!('keyboard: true,',  "keyboard: { 83: null }, // 's' disabled (was: speaker notes)")
      html.sub!('controls: true,',  'controls: false,')
      html.sub!('display: \'block\',', "display: 'flex',")
      html.gsub!(%r{  <script src="./style/revealjs/plugin/(notes|search|zoom)/\1\.js"></script>\n}, '')
      html.sub!("plugins: [\n          RevealNotes,\n          RevealSearch,\n          RevealZoom\n        ]", 'plugins: []')
      html
    end

    it 'disables the keyboard shortcut for s (speaker notes)' do
      expect(processed).to include("keyboard: { 83: null }")
      expect(processed).not_to include('keyboard: true,')
    end

    it 'disables the built-in controls' do
      expect(processed).to include('controls: false,')
      expect(processed).not_to include('controls: true,')
    end

    it 'changes display from block to flex' do
      expect(processed).to include("display: 'flex',")
      expect(processed).not_to include("display: 'block',")
    end

    it 'removes Reveal.js plugin script tags' do
      expect(processed).not_to match(%r{plugin/notes/notes\.js})
      expect(processed).not_to match(%r{plugin/search/search\.js})
      expect(processed).not_to match(%r{plugin/zoom/zoom\.js})
    end
  end

  describe 'print.html post-processing' do
    subject(:processed) do
      html = base_html.dup
      html.gsub!(/<section id="resources[-\d]*?" class="slide level2">.*?<\/section>/m, '')
      html
    end

    it 'removes Resources sections' do
      expect(processed).not_to include('id="resources-1"')
      expect(processed).not_to include('<h2>Resources</h2>')
    end

    it 'keeps non-resources sections' do
      expect(processed).to include('id="song"')
      expect(processed).to include('<h2>Song</h2>')
    end

    it 'removes the Resources section even without a numeric suffix' do
      html = base_html.sub('id="resources-1"', 'id="resources"')
      html.gsub!(/<section id="resources[-\d]*?" class="slide level2">.*?<\/section>/m, '')
      expect(html).not_to include('id="resources"')
    end
  end

  describe 'CSS injection' do
    it 'prepends custom CSS inside the style tag' do
      html = base_html.dup
      html.sub!('<style>', '<style>' + '.custom { color: red; }')
      expect(html).to include('<style>.custom { color: red; }existing')
    end
  end
end
