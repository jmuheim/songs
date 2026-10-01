require_relative '../../lib/build_helpers'

# The build outputs are no longer committed (index.html / print.html /
# all-songs.md are generated, not checked in — see
# decisions/2026-10-01-build-outputs-are-not-committed.md), so the old check
# ("committed all-songs.md matches source") has nothing left to compare.
#
# This replaces it with a guard that still earns its place and runs in CI: the
# *real* song book compiles from source. Every song in content/songs/ passes
# validate_song!, and the concatenated markdown carries the front matter, the
# introduction and every song, with chords marked up. A malformed song now
# fails here — before it can reach a deploy — which nothing else covered (the
# golden specs build the fixture songs, not the real content).
RSpec.describe 'the song book builds from the real content' do
  include BuildHelpers

  song_files = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].sort

  it 'has songs to build' do
    expect(song_files).not_to be_empty
  end

  it 'validates every song in content/songs/' do
    song_files.each do |path|
      expect { validate_song!(path, File.read(path, encoding: 'UTF-8')) }
        .not_to raise_error, "validate_song! rejected #{File.basename(path)}"
    end
  end

  it 'concatenates front matter, the introduction and every song, with chords marked up' do
    markdown = songbook_markdown(song_files, File.join(PROJECT_ROOT, 'content', 'Introduction.md'))

    expect(markdown).to start_with("---\n")
    expect(markdown).to match(/^lang:\s+de-CH$/)

    song_files.each do |path|
      h1 = File.readlines(path, encoding: 'UTF-8').find { |line| line.start_with?('# ') }
      title = h1.strip.delete_prefix('# ')
      expect(markdown).to include(title), "#{File.basename(path)} title missing from the song book"
    end

    expect(markdown).to match(/`[^`]+`\{\.[a-g]\}/) # at least one [Chord] was marked up
  end
end
