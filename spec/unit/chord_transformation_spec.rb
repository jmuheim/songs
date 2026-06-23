require_relative '../../lib/build_helpers'

RSpec.describe 'chord transformation' do
  include BuildHelpers

  describe '#transform_chords' do
    it 'transforms a chord at the start of a line' do
      expect(transform_chords("[Am] text")).to eq('`Am`{.a} text')
    end

    it 'uses the lowercase first letter as the CSS class' do
      expect(transform_chords("[G] x")).to  include('{.g}')
      expect(transform_chords("[Am] x")).to include('{.a}')
      expect(transform_chords("[A] x")).to include('{.a}')
      expect(transform_chords("[C] x")).to  include('{.c}')
      expect(transform_chords("[D7] x")).to include('{.d}')
      expect(transform_chords("[E] x")).to  include('{.e}')
      expect(transform_chords("[F] x")).to  include('{.f}')
    end

    it 'transforms a chord in the middle of text' do
      expect(transform_chords("I have a [E] dream, a song")).to \
        eq("I have a `E`{.e} dream, a song")
    end

    it 'transforms complex chord names (G7, Cmaj7, Am/E)' do
      expect(transform_chords("[G7] x")).to   eq('`G7`{.g} x')
      expect(transform_chords("[Cmaj7] x")).to eq('`Cmaj7`{.c} x')
      expect(transform_chords("[Am/E] x")).to  eq('`Am/E`{.a} x')
    end

    it 'transforms multiple chords on one line' do
      result = transform_chords("[Am] [G] [E] end")
      expect(result).to eq('`Am`{.a} `G`{.g} `E`{.e} end')
    end

    it 'transforms a chord followed by a newline' do
      expect(transform_chords("[Am]\nmore")).to eq("`Am`{.a}\nmore")
    end

    it 'does NOT transform Markdown links [text](url)' do
      text = "[Song](https://youtube.com/watch?v=abc)"
      expect(transform_chords(text)).to eq(text)
    end

    it 'does NOT transform lowercase bracket content' do
      expect(transform_chords("[am] text")).to eq("[am] text")
    end

    it 'does NOT transform single lowercase letters like [a]' do
      expect(transform_chords("[a] x")).to eq("[a] x")
    end

    it 'leaves standard text unchanged' do
      expect(transform_chords("no chords here")).to eq("no chords here")
    end

    it 'transforms a chord that is the very last character(s) in a string with no trailing char' do
      expect(transform_chords("[Am]")).to eq('`Am`{.a}')
    end

    it 'handles a chord immediately followed by end-of-line newline' do
      # In real song files every line ends with \n, so this is the common case
      expect(transform_chords("[Am]\n")).to eq("`Am`{.a}\n")
    end

    it 'handles back-to-back chords separated only by a space' do
      # "[Am] [G] " — second chord must also be transformed
      expect(transform_chords("[Am] [G] ")).to eq('`Am`{.a} `G`{.g} ')
    end

    it 'handles a chord whose name contains a slash (Am/E)' do
      expect(transform_chords("[Am/E] x")).to include('`Am/E`{.a}')
    end

    it 'preserves the character after the chord in the output' do
      expect(transform_chords("[G],next")).to eq('`G`{.g},next')
    end

    it 'handles real song line from ABBA' do
      line = "[A] I have a [E] dream, a song to [A] sing\n"
      result = transform_chords(line)
      expect(result).to eq("`A`{.a} I have a `E`{.e} dream, a song to `A`{.a} sing\n")
    end
  end
end
