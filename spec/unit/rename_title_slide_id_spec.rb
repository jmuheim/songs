require_relative '../../lib/build_helpers'

RSpec.describe 'rename_title_slide_id' do
  include BuildHelpers

  it 'swaps the id for a "deck-title-slide" class, dropping the id entirely' do
    html = '<section id="title-slide"><div class="slide-content"><h1 class="title">Lieblings-Songs</h1></div></section>'
    out = rename_title_slide_id(html)
    expect(out).to include('<section class="deck-title-slide">')
    expect(out).not_to include('id="title-slide"')
  end

  it 'does not touch a song\'s own slide, even one that happens to have "title" in its id' do
    html = '<section id="title-track"><h1 class="title">Title Track</h1></section>'
    expect(rename_title_slide_id(html)).to eq(html)
  end

  it 'is idempotent — a second pass over already-renamed markup is a no-op' do
    html = '<section id="title-slide"><h1 class="title">Lieblings-Songs</h1></section>'
    once = rename_title_slide_id(html)
    twice = rename_title_slide_id(once)
    expect(twice).to eq(once)
  end

  it 'leaves input with no title slide at all unchanged' do
    html = '<section id="riptide" class="title-slide slide level1"><h1>Riptide - Vance Joy</h1></section>'
    expect(rename_title_slide_id(html)).to eq(html)
  end
end
