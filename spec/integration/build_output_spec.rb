require_relative '../../lib/build_helpers'

RSpec.describe 'all-songs.md golden file' do
  include BuildHelpers

  # Regenerate all-songs.md with the build's own helper and compare it with the
  # committed copy: a song edited without re-running ./build fails here, with
  # a diff of what changed.

  let(:committed) { File.read(File.join(PROJECT_ROOT, 'all-songs.md'), encoding: 'UTF-8') }

  let(:regenerated) do
    songbook_markdown(Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].sort,
                      File.join(PROJECT_ROOT, 'content', 'Introduction.md'))
  end

  it 'matches the committed copy when regenerated from source' do
    expect(committed).to eq(regenerated)
  end
end
