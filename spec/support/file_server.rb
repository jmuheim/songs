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

  def self.url(path = '')
    "http://127.0.0.1:#{@port}/#{path.sub(%r{^/}, '')}"
  end
end
