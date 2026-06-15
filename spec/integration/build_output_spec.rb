require_relative '../../lib/build_helpers'

RSpec.describe 'all-songs.md golden file' do
  include BuildHelpers

  # Reproduce exactly what the build script writes to all-songs.md and compare
  # against the committed copy.  If a song file is edited without re-running
  # ./build, or if the chord-transformation logic drifts, this test will fail
  # and show a clear diff of what changed.

  let(:committed) { File.read(File.join(PROJECT_ROOT, 'all-songs.md'), encoding: 'UTF-8') }

  let(:regenerated) do
    song_files = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].sort

    frontmatter = <<~MD
      ---
      title:  Lieblings-Songs 🔥🎶🌛
      author: 😊 Josua & Monika ❤️
      ---
    MD

    songs_md = song_files.map do |f|
      transform_chords(File.read(f, encoding: 'UTF-8'))
    end

    introduction = File.read(
      File.join(PROJECT_ROOT, 'content', 'Introduction.md'), encoding: 'UTF-8'
    )

    parts = [frontmatter, introduction, *songs_md].map(&:rstrip)
    parts.join("\n\n") + "\n"
  end

  it 'matches the committed copy when regenerated from source' do
    expect(committed).to eq(regenerated)
  end
end
