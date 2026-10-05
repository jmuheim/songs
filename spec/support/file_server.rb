require 'webrick'

# Serves the project root to the browser specs, on a port the OS picks: a
# fixed one collided with a second checkout's run. Unlike MultiplexServer's,
# this port appears nowhere in the committed fixtures.
module FileServer
  ROOT = File.expand_path('../..', __dir__)

  @started = false
  @mutex   = Mutex.new

  def self.start
    @mutex.synchronize do
      return if @started

      @server = WEBrick::HTTPServer.new(
        BindAddress:  '127.0.0.1',
        Port:         0,
        DocumentRoot: ROOT,
        Logger:       WEBrick::Log.new(File::NULL),
        AccessLog:    []
      )
      @port = @server.listeners.first.addr[1]
      Thread.new { @server.start }
      @started = true
      at_exit { @server.shutdown }
    end
  end

  # No argument (every spec's Capybara.app_host = FileServer.url) must come
  # back with no trailing slash: Capybara's own Session#visit builds the
  # final path as `base_uri.path + visit_uri.path`, naive string
  # concatenation rather than a slash-aware join. A trailing "/" here plus
  # the leading "/" on every spec's own absolute path (e.g.
  # FixtureBuilder::URL_PATH) used to double up into "//spec/fixtures/…".
  # That stayed harmless as long as nothing ever fed location.pathname
  # straight back into history.replaceState — a path starting with "//" is
  # a protocol-relative reference, so the browser read the doubled slash as
  # "no scheme, host is the next path segment" and silently repointed the
  # document at a nonexistent host (e.g. "http://spec"), breaking every
  # absolute-path asset request after it. See
  # decisions/2026-10-05-title-slide-id-replaced-with-a-class.md.
  def self.url(path = '')
    path = path.sub(%r{^/}, '')
    "http://127.0.0.1:#{@port}" + (path.empty? ? '' : "/#{path}")
  end
end
