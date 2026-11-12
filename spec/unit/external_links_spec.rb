require 'nokogiri'
require_relative '../../lib/build_helpers'

RSpec.describe 'external_links' do
  include BuildHelpers

  def parse(html)
    Nokogiri::HTML(external_links(%(<div class="reveal"><div class="slides"><section>#{html}</section></div></div>)))
  end

  it "plays a YouTube link in the song book's own player: its embed address, from youtube-nocookie.com" do
    doc = parse('<a href="https://www.youtube.com/watch?v=90M60PzmxEE">Lied auf YouTube</a>')
    link = doc.at_css('a')
    expect(link['data-video']).to eq('https://www.youtube-nocookie.com/embed/90M60PzmxEE?autoplay=1')
    expect(link['href']).to eq('https://www.youtube.com/watch?v=90M60PzmxEE') # still there, for a click with a modifier key
    expect(link['target']).to be_nil
  end

  it 'finds the video in a watch address with more parameters, and in a youtu.be one' do
    expect(youtube_embed('https://www.youtube.com/watch?v=ER_3h03omdE&pp=ygUJYmVsZSBtYW1h')).to eq('https://www.youtube-nocookie.com/embed/ER_3h03omdE?autoplay=1')
    expect(youtube_embed('https://youtu.be/t590jjWEJ5s')).to eq('https://www.youtube-nocookie.com/embed/t590jjWEJ5s?autoplay=1')
  end

  it "opens any other link in a new tab: YouTube's other pages and the tab sites refuse to be framed" do
    doc = parse(<<~HTML)
      <a href="https://tabs.ultimate-guitar.com/tab/the-beatles/across-the-universe-chords-202167">Tab-Quelle</a>
      <a href="https://www.youtube.com/@thebeatles">Kanal</a>
      <a href="https://www.youtube.com/watch?v=">kein Video</a>
    HTML
    doc.css('a').each do |link|
      expect(link['target']).to eq('_blank'), link.text
      expect(link['rel']).to eq('noopener'), link.text
      expect(link['data-video']).to be_nil, link.text
    end
  end

  it "leaves the song book's own links alone, and anything outside the slides" do
    doc = Nokogiri::HTML(external_links(<<~HTML))
      <div class="reveal"><div class="slides"><section><a href="#/imagine-john-lennon">Imagine</a></section></div></div>
      <a href="https://www.youtube.com/watch?v=90M60PzmxEE">outside</a>
    HTML
    doc.css('a').each { |link| expect(link.attributes.keys).to eq(['href']), link.text }
  end
end
