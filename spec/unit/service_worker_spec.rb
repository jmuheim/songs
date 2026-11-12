require 'tmpdir'
require 'fileutils'
require_relative '../../lib/build_helpers'

RSpec.describe 'service_worker' do
  include BuildHelpers

  around do |example|
    Dir.mktmpdir('sw-spec-') do |root|
      @root = root
      FileUtils.mkdir_p(File.join(root, 'style', 'revealjs'))
      File.write(File.join(root, 'style', 'chords.js'), 'chords')
      File.write(File.join(root, 'style', 'revealjs', 'reveal.css'), 'reveal')
      example.run
    end
  end

  let(:page) do
    <<~HTML
      <html><head>
        <link rel="stylesheet" href="./style/revealjs/reveal.css">
        <link rel="icon" href="style/icon.png">
      </head><body>
        <script>window.MULTIPLEX = {};</script>
        <script src="style/chords.js"></script>
        <script src="https://cdn.example.com/elsewhere.js"></script>
        <script src="//cdn.example.com/elsewhere-too.js"></script>
      </body></html>
    HTML
  end

  def files(js)
    JSON.parse(js[/^const FILES = (.*);$/, 1])
  end

  def version(js)
    js[/^const VERSION = '(\h+)';$/, 1]
  end

  it "keeps every script and stylesheet the page loads from its own site, read off the page itself" do
    expect(files(service_worker(page, root: @root))).to eq(['./style/revealjs/reveal.css', 'style/chords.js'])
  end

  it 'finds them from the root whether the page names them relative or absolute (the fixtures: /style/…)' do
    absolute = page.gsub('"./style/', '"/style/').gsub('"style/', '"/style/')
    expect(files(service_worker(absolute, root: @root))).to eq(['/style/revealjs/reveal.css', '/style/chords.js'])
  end

  it 'is another version, so another sw.js, as soon as the page or a file it keeps changes, and only then' do
    before = version(service_worker(page, root: @root))
    expect(before).not_to be_nil
    expect(version(service_worker(page, root: @root))).to eq(before)

    expect(version(service_worker(page.sub('</body>', '<p>new</p></body>'), root: @root))).not_to eq(before)

    File.write(File.join(@root, 'style', 'chords.js'), 'chords, changed')
    expect(version(service_worker(page, root: @root))).not_to eq(before)
  end
end
