require 'nokogiri'
require_relative '../../lib/build_helpers'

RSpec.describe 'split_song_artist' do
  include BuildHelpers

  def parse(html)
    Nokogiri::HTML(split_song_artist(html))
  end

  it 'splits a song title-slide h1 into a bare h1 and a sibling p.song-artist' do
    html = '<section id="riptide" class="title-slide slide level1"><h1>Riptide - Vance Joy</h1></section>'
    doc = parse(html)
    h1 = doc.at_css('section#riptide h1')
    artist = doc.at_css('section#riptide p.song-artist')
    expect(h1.text).to eq('Riptide')
    expect(artist.text).to eq('Vance Joy')
  end

  it 'places the p.song-artist as the h1\'s immediate next sibling, so wrap_slide_content carries both into one .slide-content' do
    html = '<section id="riptide" class="title-slide slide level1"><h1>Riptide - Vance Joy</h1></section>'
    doc = Nokogiri::HTML(wrap_slide_content(split_song_artist(html)))
    wrapper = doc.at_css('section#riptide .slide-content')
    expect(wrapper.element_children.map(&:name)).to eq(%w[h1 p])
    expect(wrapper.at_css('p').text).to eq('Vance Joy')
  end

  it 'leaves an h1 with no " - " untouched' do
    html = '<section id="introduction" class="title-slide slide level1"><h1>Introduction</h1></section>'
    doc = parse(html)
    expect(doc.at_css('section#introduction h1').text).to eq('Introduction')
    expect(doc.at_css('section#introduction p.song-artist')).to be_nil
  end

  it 'does not mistake an unspaced hyphen inside the title for the artist separator' do
    html = '<section id="the-connells" class="title-slide slide level1"><h1>74-75 - The Connells</h1></section>'
    doc = parse(html)
    expect(doc.at_css('section#the-connells h1').text).to eq('74-75')
    expect(doc.at_css('section#the-connells p.song-artist').text).to eq('The Connells')
  end

  it 'splits on the last " - " when the title itself legitimately contains one' do
    html = '<section id="s" class="title-slide slide level1"><h1>A - B - C</h1></section>'
    doc = parse(html)
    expect(doc.at_css('section#s h1').text).to eq('A - B')
    expect(doc.at_css('section#s p.song-artist').text).to eq('C')
  end

  it 'only touches section.level1, never the deck\'s own #title-slide' do
    html = <<~HTML
      <section id="title-slide"><h1 class="title">Lieblings-Songs - the book</h1></section>
      <section id="riptide" class="title-slide slide level1"><h1>Riptide - Vance Joy</h1></section>
    HTML
    doc = parse(html)
    expect(doc.at_css('#title-slide h1').text).to eq('Lieblings-Songs - the book')
    expect(doc.at_css('#title-slide p.song-artist')).to be_nil
    expect(doc.at_css('#riptide p.song-artist').text).to eq('Vance Joy')
  end

  it 'round-trips an ampersand and an emoji through the split' do
    html = '<section id="s" class="title-slide slide level1"><h1>Rock &amp; Roll - AC/DC 🎸</h1></section>'
    doc = parse(html)
    expect(doc.at_css('section#s h1').text).to eq('Rock & Roll')
    expect(doc.at_css('section#s p.song-artist').text).to eq('AC/DC 🎸')
    expect(split_song_artist(html)).to include('Rock &amp; Roll')
  end
end
