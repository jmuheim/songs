require_relative '../../lib/build_helpers'

RSpec.describe 'BuildHelpers#validate_song!' do
  include BuildHelpers

  ABOUT = "## Infos über das Lied\n\n- Sprache: Englisch\n- Genre: Pop\n\n"

  def valid_content
    "# My Song\n\n#{ABOUT}## Verse\n\nLyrics here\n"
  end

  def expect_abort(content, message_fragment)
    expect(self).to receive(:abort).with(include(message_fragment))
    validate_song!('song.md', content)
  end

  def expect_valid(content)
    expect { validate_song!('song.md', content) }.not_to raise_error
  end

  it 'accepts a well-formed song' do
    expect_valid(valid_content)
  end

  describe 'H1 heading' do
    it 'rejects a file with no H1' do
      expect_abort("#{ABOUT}## Verse\n\nLyrics\n", 'must have exactly one H1 (found 0)')
    end

    it 'rejects a file with more than one H1' do
      expect_abort("# Title One\n\n# Title Two\n\n#{ABOUT}## Verse\n\nLyrics\n", 'must have exactly one H1 (found 2)')
    end
  end

  describe 'H2 sections' do
    it 'rejects a file with no H2' do
      expect_abort("# My Song\n\nJust a paragraph\n", 'must have at least one H2 section (found 0)')
    end
  end

  describe 'brackets' do
    it 'rejects unmatched opening bracket' do
      expect_abort("# My Song\n\n#{ABOUT}## Verse\n\n[Am text\n", 'has mismatched brackets (1 [ vs 0 ])')
    end

    it 'rejects unmatched closing bracket' do
      expect_abort("# My Song\n\n#{ABOUT}## Verse\n\nAm] text\n", 'has mismatched brackets (0 [ vs 1 ])')
    end

    it 'accepts balanced brackets' do
      expect_valid("# My Song\n\n#{ABOUT}## Verse\n\n[Am] text\n")
    end
  end

  describe 'chord names with spaces' do
    it 'rejects a chord-like token with a space' do
      expect_abort("# My Song\n\n#{ABOUT}## Verse\n\n[Am G] text\n", 'has chord names with spaces: ["Am G"]')
    end

    it 'accepts lowercase bracket content (not treated as a chord)' do
      expect_valid("# My Song\n\n#{ABOUT}## Verse\n\n[some note]\n")
    end
  end

  describe 'line endings' do
    it 'rejects Windows line endings' do
      expect_abort("# My Song\r\n\r\n#{ABOUT.gsub("\n", "\r\n")}## Verse\r\n\r\nLyrics\r\n", 'must not have Windows line endings')
    end
  end

  describe 'Sprache/Genre tags' do
    it 'rejects a song with no "Infos über das Lied" section at all' do
      expect_abort(
        "# My Song\n\n## Verse\n\nLyrics\n",
        'is missing a Sprache tag in its "Infos über das Lied" section; is missing a Genre tag in its "Infos über das Lied" section'
      )
    end

    it 'rejects a song missing the Genre tag' do
      expect_abort(
        "# My Song\n\n## Infos über das Lied\n\n- Sprache: Englisch\n\n## Verse\n\nLyrics\n",
        'is missing a Genre tag in its "Infos über das Lied" section'
      )
    end

    it 'rejects a song missing the Sprache tag' do
      expect_abort(
        "# My Song\n\n## Infos über das Lied\n\n- Genre: Pop\n\n## Verse\n\nLyrics\n",
        'is missing a Sprache tag in its "Infos über das Lied" section'
      )
    end

    it 'accepts a song with both tags present' do
      expect_valid(valid_content)
    end

    it 'accepts a Sprache/Genre value this book has never seen before (category comes from the label, not a fixed vocabulary)' do
      expect_valid("# My Song\n\n## Infos über das Lied\n\n- Sprache: Spanisch\n- Genre: Traditional\n\n## Verse\n\nLyrics\n")
    end
  end

  describe 'content between the H1 and the first H2' do
    it 'rejects a stray line (e.g. a Capo note) left outside the "Infos über das Lied" list' do
      expect_abort(
        "# My Song\n\n_Capo 3. Bund_\n\n#{ABOUT}## Verse\n\nLyrics\n",
        'has content between the H1 and the first H2 — move it into "Infos über das Lied": ["_Capo 3. Bund_"]'
      )
    end

    it 'accepts a song with nothing but blank lines between the H1 and the first H2' do
      expect_valid(valid_content)
    end
  end
end
