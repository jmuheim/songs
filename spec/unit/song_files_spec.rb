RSpec.describe 'song files' do
  let(:song_dir) { File.join(PROJECT_ROOT, 'content', 'songs') }
  let(:song_files) { Dir["#{song_dir}/*.md"].sort }

  it 'finds at least one song' do
    expect(song_files).not_to be_empty
  end

  describe 'each song file' do
    song_dir = File.join(File.expand_path('../..', __dir__), 'content', 'songs')

    Dir["#{song_dir}/*.md"].sort.each do |path|
      basename = File.basename(path)
      content  = File.read(path, encoding: 'UTF-8')
      lines    = content.lines

      context basename do
        it 'has exactly one H1 heading' do
          h1s = lines.select { |l| l.start_with?('# ') }
          expect(h1s.size).to eq(1), "Expected 1 H1, got: #{h1s.inspect}"
        end

        it 'has at least one H2 section' do
          h2s = lines.select { |l| l.start_with?('## ') }
          expect(h2s.size).to be >= 1
        end

        it 'has UTF-8 encoding' do
          expect(content.encoding.name).to eq('UTF-8')
          expect(content).to be_valid_encoding
        end

        it 'does not have Windows line endings' do
          expect(content).not_to include("\r\n")
        end

        it 'ends with a newline' do
          expect(content).to end_with("\n")
        end

        it 'has only valid chord names (uppercase start, no spaces inside brackets)' do
          chord_like = content.scan(/\[([^\]]+)\](?!\()/).flatten
          bad = chord_like.select { |c| c =~ /^[A-Z]/ && c.include?(' ') }
          expect(bad).to be_empty, "Suspicious chord with space: #{bad.inspect}"
        end

        it 'does not contain unclosed brackets' do
          opens  = content.count('[')
          closes = content.count(']')
          expect(opens).to eq(closes), "Mismatched brackets: #{opens} [ vs #{closes} ]"
        end
      end
    end
  end
end
