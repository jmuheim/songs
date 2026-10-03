require 'json'
require 'fileutils'
require_relative '../../lib/build_helpers'
require_relative 'multiplex_server'

module FixtureBuilder
  extend BuildHelpers

  ROOT          = File.expand_path('../..', __dir__)
  FIXTURE_DIR   = File.join(ROOT, 'spec', 'fixtures')
  SONGS_DIR     = File.join(FIXTURE_DIR, 'songs')
  OUTPUT        = File.join(FIXTURE_DIR, 'index.html')
  PRINT_OUTPUT  = File.join(FIXTURE_DIR, 'print.html')
  URL_PATH      = '/spec/fixtures/index.html'
  PRINT_URL_PATH = '/spec/fixtures/print.html'

  def self.build!
    return if @built

    song_files = Dir[File.join(SONGS_DIR, '*.md')].sort
    raise "No fixture songs found in #{SONGS_DIR}" if song_files.empty?

    Dir.mktmpdir('fixture-build-') do |tmpdir|
      md_path = File.join(tmpdir, 'all-songs.md')
      File.write(md_path, songbook_markdown(song_files, File.join(ROOT, 'content', 'Introduction.md')), encoding: 'UTF-8')

      # Absolute paths, so the pages work when served from /spec/fixtures/
      index_path = File.join(tmpdir, 'index.html')
      print_path = File.join(tmpdir, 'print.html')
      pandoc!(md_path, index_path, theme: 'night', revealjs_url: '/style/revealjs')
      pandoc!(md_path, print_path, theme: 'serif', revealjs_url: '/style/revealjs')

      multiplex = { url: MultiplexServer.url, socketId: MultiplexServer::SOCKET_ID,
                    secret: MultiplexServer::SECRET, password: 'guitar' }

      tags = song_files.map { |file| song_tags(File.read(file, encoding: 'UTF-8')) }

      FileUtils.mkdir_p(FIXTURE_DIR)
      File.write(OUTPUT, post_process_index(File.read(index_path, encoding: 'UTF-8'), assets: '/style/', multiplex: multiplex, tags: tags), encoding: 'UTF-8')
      File.write(PRINT_OUTPUT, post_process_print(File.read(print_path, encoding: 'UTF-8'), assets: '/style/'), encoding: 'UTF-8')
    end

    @built = true
  end
end
