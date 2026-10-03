require_relative '../../lib/build_helpers'

RSpec.describe '#song_tags' do
  include BuildHelpers

  it 'returns [] when there is no About section' do
    expect(song_tags("# Song (X)\n\n## Verse 1\n\n[C] la\n")).to eq([])
  end

  it 'extracts the list items of the About section, in order' do
    content = "# Song (X)\n\n## About\n\n- Englisch\n- Mantra\n\n## Verse 1\n\n[C] la\n"
    expect(song_tags(content)).to eq(%w[Englisch Mantra])
  end

  it 'stops at the next section (a list there is not tags)' do
    content = "# S\n\n## About\n\n- Pop\n\n## Verse 1\n\n- not a tag\n"
    expect(song_tags(content)).to eq(['Pop'])
  end

  it 'ignores prose in the About section, keeping only list items' do
    content = "# S\n\n## About\n\nSome note about the song.\n\n- Rock\n\n## Verse 1\n"
    expect(song_tags(content)).to eq(['Rock'])
  end

  it 'trims surrounding whitespace from each tag' do
    content = "# S\n\n## About\n\n-   Deutsch  \n-\tMundart\n\n## Verse 1\n"
    expect(song_tags(content)).to eq(%w[Deutsch Mundart])
  end

  it 'accepts * list markers as well as -' do
    content = "# S\n\n## About\n\n* Englisch\n* Pop\n\n## Verse 1\n"
    expect(song_tags(content)).to eq(%w[Englisch Pop])
  end

  it 'allows multi-word tags' do
    content = "# S\n\n## About\n\n- Hip Hop\n\n## Verse 1\n"
    expect(song_tags(content)).to eq(['Hip Hop'])
  end

  it 'handles the About section being last, with nothing after it' do
    content = "# S\n\n## Verse 1\n\n[C] la\n\n## About\n\n- Mantra\n"
    expect(song_tags(content)).to eq(['Mantra'])
  end

  it 'matches the About heading case-insensitively' do
    expect(song_tags("# S\n\n## about\n\n- Pop\n\n## Verse 1\n")).to eq(['Pop'])
  end
end
