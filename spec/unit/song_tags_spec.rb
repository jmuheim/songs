require_relative '../../lib/build_helpers'

RSpec.describe '#song_tags' do
  include BuildHelpers

  it 'returns [] when there is no "Infos über das Lied" section' do
    expect(song_tags("# Song (X)\n\n## Verse 1\n\n[C] la\n")).to eq([])
  end

  it 'extracts the Sprache/Genre list items of the "Infos über das Lied" section, as [category, value] pairs, in order' do
    content = "# Song (X)\n\n## Infos über das Lied\n\n- Sprache: Englisch\n- Genre: Mantra\n\n## Verse 1\n\n[C] la\n"
    expect(song_tags(content)).to eq([%w[Sprache Englisch], %w[Genre Mantra]])
  end

  it 'takes the category from what was written, not a fixed vocabulary (so an unseen language/genre still classifies correctly)' do
    content = "# S\n\n## Infos über das Lied\n\n- Sprache: Spanisch\n- Genre: Traditional\n\n## Verse 1\n"
    expect(song_tags(content)).to eq([%w[Sprache Spanisch], %w[Genre Traditional]])
  end

  it 'ignores resource links and other list items (e.g. a Capo note), which are not tags' do
    content = "# S\n\n## Infos über das Lied\n\n- Capo: 3. Bund\n- Sprache: Pop\n- [Lied auf YouTube](http://example.com)\n\n## Verse 1\n"
    expect(song_tags(content)).to eq([%w[Sprache Pop]])
  end

  it 'stops at the next section' do
    content = "# S\n\n## Infos über das Lied\n\n- Genre: Pop\n\n## Verse 1\n\n- not a tag\n"
    expect(song_tags(content)).to eq([%w[Genre Pop]])
  end

  it 'trims surrounding whitespace from each tag value' do
    content = "# S\n\n## Infos über das Lied\n\n-   Sprache:   Deutsch  \n-\tGenre:\tMundart\n\n## Verse 1\n"
    expect(song_tags(content)).to eq([%w[Sprache Deutsch], %w[Genre Mundart]])
  end

  it 'accepts * list markers as well as -' do
    content = "# S\n\n## Infos über das Lied\n\n* Sprache: Englisch\n* Genre: Pop\n\n## Verse 1\n"
    expect(song_tags(content)).to eq([%w[Sprache Englisch], %w[Genre Pop]])
  end

  it 'allows multi-word tag values' do
    content = "# S\n\n## Infos über das Lied\n\n- Genre: Hip Hop\n\n## Verse 1\n"
    expect(song_tags(content)).to eq([['Genre', 'Hip Hop']])
  end

  it 'handles the section being last, with nothing after it' do
    content = "# S\n\n## Verse 1\n\n[C] la\n\n## Infos über das Lied\n\n- Genre: Mantra\n"
    expect(song_tags(content)).to eq([%w[Genre Mantra]])
  end

  it 'matches the heading case-insensitively, and normalizes the tag keyword case' do
    expect(song_tags("# S\n\n## infos über das lied\n\n- genre: Pop\n\n## Verse 1\n")).to eq([%w[Genre Pop]])
  end
end
