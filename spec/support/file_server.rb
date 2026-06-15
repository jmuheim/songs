require 'webrick'

module FileServer
  PORT = 18_888
  ROOT = File.expand_path('../..', __dir__)

  @started = false
  @mutex   = Mutex.new

  def self.start
    @mutex.synchronize do
      return if @started

      @server = WEBrick::HTTPServer.new(
        Port:        PORT,
        DocumentRoot: ROOT,
        Logger:      WEBrick::Log.new(File::NULL),
        AccessLog:   []
      )
      Thread.new { @server.start }
      @started = true
      at_exit { @server.shutdown }
    end
  end

  def self.url(path = '')
    "http://localhost:#{PORT}/#{path.sub(%r{^/}, '')}"
  end
end
