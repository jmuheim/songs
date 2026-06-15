require 'nokogiri'

RSpec.describe 'build output' do
  let(:index_html)  { File.read(File.join(PROJECT_ROOT, 'index.html'),     encoding: 'UTF-8') }
  let(:print_html)  { File.read(File.join(PROJECT_ROOT, 'print.html'),     encoding: 'UTF-8') }
  let(:index_doc)   { Nokogiri::HTML(index_html) }
  let(:print_doc)   { Nokogiri::HTML(print_html) }

  describe 'index.html' do
    it 'exists' do
      expect(File.exist?(File.join(PROJECT_ROOT, 'index.html'))).to be true
    end

    it 'embeds the multiplex config as a window global' do
      expect(index_html).to match(/window\.MULTIPLEX\s*=\s*\{/)
      expect(index_html).to include('"socketId"')
      expect(index_html).to include('"secret"')
      expect(index_html).to include('"url"')
    end

    it 'has the song book title in a title slide' do
      title_slide = index_doc.at_css('#title-slide')
      expect(title_slide).not_to be_nil
      expect(title_slide.text).to include('Lieblings-Songs')
    end

    it 'inlines chord CSS for all note letters' do
      %w[a b c d e f g].each do |letter|
        expect(index_html).to include("code.#{letter}"), "Missing chord CSS for .#{letter}"
      end
    end

    it 'wraps slide sections in .slide-content divs' do
      expect(index_doc.css('.slide-content').size).to be > 0
    end

    it 'disables built-in controls' do
      expect(index_html).to include('controls: false,')
    end

    it 'uses flex display for slides' do
      expect(index_html).to include("display: 'flex',")
    end

    it 'disables the s key (speaker notes shortcut)' do
      expect(index_html).to include('keyboard: { 83: null }')
    end

    it 'removes plugin script tags for notes/search/zoom' do
      expect(index_html).not_to match(%r{plugin/notes/notes\.js})
      expect(index_html).not_to match(%r{plugin/search/search\.js})
      expect(index_html).not_to match(%r{plugin/zoom/zoom\.js})
    end

    it 'has chord <code> elements with correct CSS classes' do
      code_elements = index_doc.css('section code')
      expect(code_elements).not_to be_empty
      classes = code_elements.flat_map { |el| el['class']&.split || [] }
      expect(classes).to include('a', 'e', 'g')
    end

    it 'includes the master password field' do
      expect(index_html).to include('"password"')
    end

    it 'includes socket.io script from multiplex server' do
      expect(index_html).to include('socket.io.js')
    end

    it 'includes QR code library' do
      expect(index_html).to include('qrcode')
    end

    it 'includes the slide-zoom script' do
      expect(index_html).to include('slide-zoom.js')
    end

    it 'has a slide for each active song (plus introduction)' do
      song_count = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].size
      level1_sections = index_doc.css('section.level1')
      expect(level1_sections.size).to eq(song_count + 1)
    end

    it 'contains the TOC' do
      toc = index_doc.at_css('#TOC')
      expect(toc).not_to be_nil
    end
  end

  describe 'print.html' do
    it 'exists' do
      expect(File.exist?(File.join(PROJECT_ROOT, 'print.html'))).to be true
    end

    it 'has no Resources sections' do
      resources = print_doc.css('section[id^="resources"]')
      expect(resources).to be_empty
    end

    it 'has no "Resources" heading text' do
      h2_texts = print_doc.css('h2').map(&:text)
      expect(h2_texts).not_to include('Resources')
    end

    it 'inlines chord CSS' do
      %w[a b c d e f g].each do |letter|
        expect(print_html).to include("code.#{letter}")
      end
    end

    it 'wraps slide sections in .slide-content divs' do
      expect(print_doc.css('.slide-content').size).to be > 0
    end

    it 'has chord <code> elements' do
      expect(print_doc.css('section code')).not_to be_empty
    end

    it 'uses the serif theme' do
      expect(print_html).to match(/theme=serif|theme\/serif\.css/i)
    end

    it 'sets the title slide background image' do
      title = print_doc.at_css('#title-slide')
      expect(title['data-background-image']).to include('background.jpg')
    end

    it 'removes plugin script tags for notes/search/zoom' do
      expect(print_html).not_to match(%r{plugin/notes/notes\.js})
    end
  end

  describe 'all-songs.md' do
    let(:all_songs) { File.read(File.join(PROJECT_ROOT, 'all-songs.md'), encoding: 'UTF-8') }

    it 'starts with YAML front matter' do
      expect(all_songs).to start_with("---\n")
    end

    it 'includes the title' do
      expect(all_songs).to include('Lieblings-Songs')
    end

    it 'contains chord spans for every note letter' do
      %w[a e g].each do |letter|
        expect(all_songs).to include("{.#{letter}}"), "Missing chord span {.#{letter}}"
      end
    end

    it 'does not contain raw [Am]-style chord brackets after transformation' do
      # Any remaining [X...] that starts with uppercase must be gone
      raw_chords = all_songs.scan(/\[([A-Z][^\]]*)\](?!\()/).flatten
      expect(raw_chords).to be_empty,
        "Found untransformed chord(s): #{raw_chords.first(5).inspect}"
    end
  end
end
