require_relative '../../lib/build_helpers'

RSpec.describe '#merge_about_section' do
  include BuildHelpers

  it 'passes content through unchanged when there is no "Infos über das Lied" section' do
    content = "# S (X)\n\n## Refrain\n\nLa [C] la\n"
    expect(merge_about_section(content)).to eq(content)
  end

  it 'leaves a song with no Spielhinweise section untouched aside from the section split' do
    content = "# S (X)\n\n## Infos über das Lied\n\n- Sprache: Englisch\n- Genre: Pop\n- [Lied auf YouTube](http://example.com)\n\n## Refrain\n\nLa [C] la\n"
    expect(merge_about_section(content)).to eq(content)
  end

  it 'splices Spielhinweise (alternate chord fingerings) into the Infos-über-das-Lied section' do
    content = <<~MD
      # S (X)

      ## Infos über das Lied

      - Sprache: Englisch
      - Genre: Pop

      ## Spielhinweise

      ```
      |E A D G B e|
      A7sus4 |x 0 2 0 3 0|
      ```

      ## Refrain

      La [C] la
    MD

    expect(merge_about_section(content)).to eq(<<~MD)
      # S (X)

      ## Infos über das Lied

      - Sprache: Englisch
      - Genre: Pop

      ```
      |E A D G B e|
      A7sus4 |x 0 2 0 3 0|
      ```

      ## Refrain

      La [C] la
    MD
  end
end
