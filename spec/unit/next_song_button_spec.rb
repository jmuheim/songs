require 'nokogiri'
require_relative '../../lib/build_helpers'

RSpec.describe 'inject_next_song_buttons' do
  include BuildHelpers

  # The shape inject_next_line_previews leaves a song in: a stack <section>
  # with its title slide (level1) and its sub-slides (level2), each sung one
  # ending on its preview, inside div.slides. The first stack is always the
  # Introduction.
  def deck(*stacks)
    %(<div class="reveal"><div class="slides">#{stacks.join}</div></div>)
  end

  INTRO_STACK = <<~HTML.freeze
    <section>
    <section id="einleitung" class="title-slide slide level1"><h1>Einleitung</h1></section>
    <section id="willkommen" class="slide level2"><h2>Willkommen</h2><p>Hello</p></section>
    </section>
  HTML

  SONG_STACK = <<~HTML.freeze
    <section>
    <section id="riptide" class="title-slide slide level1"><h1>Riptide</h1></section>
    <section id="intro" class="slide level2"><h2>Intro</h2><p>Am G</p><p class="next-line">Danach: …</p></section>
    <section id="refrain" class="slide level2"><h2>Refrain</h2><p>Lady</p><p class="next-line next-line-end">Ende des Lieds</p></section>
    <section id="infos-über-das-lied" class="slide level2"><h2>Infos über das Lied</h2><ul><li>Sprache: Englisch</li></ul></section>
    </section>
  HTML

  let(:doc) { Nokogiri::HTML(inject_next_song_buttons(deck(INTRO_STACK, SONG_STACK))) }

  it 'puts one hidden button on the last sung slide of a song, after its „Ende des Lieds“, for the script to fill in' do
    buttons = doc.css('button.playlist-next')
    expect(buttons.size).to eq(1)
    button = buttons.first
    expect(button.parent['id']).to eq('refrain') # not the Infos slide, though it comes later here
    expect(button.previous_element['class']).to eq('next-line next-line-end')
    expect(button['type']).to eq('button')
    expect(button.key?('hidden')).to be true
    expect(button.at_css('.playlist-next-title').text).to eq('')
    expect(button.text).to eq('⏭️ Nächstes Lied: «»')
    expect(button.at_css('span[aria-hidden="true"]').text).to eq('⏭️')
  end

  it 'leaves the Introduction alone, which is no song' do
    expect(doc.css('section#willkommen button.playlist-next')).to be_empty
  end
end
