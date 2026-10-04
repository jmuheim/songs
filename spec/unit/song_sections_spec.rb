require_relative '../../lib/build_helpers'

RSpec.describe '#song_sections' do
  include BuildHelpers

  it 'terminates the last line with "\n" even when the source file has none at EOF' do
    # Regression: a file missing its trailing newline at EOF left the last
    # section's last line without its own "\n", which merge_about_section
    # then carried along when relocating that section ahead of others —
    # swallowing the blank line that should separate it from what follows.
    _title, sections = song_sections("# S (X)\n\n## Resources\n\n- [Song](http://example.com)")
    expect(sections.last[:lines].last).to eq("- [Song](http://example.com)\n")
  end
end
