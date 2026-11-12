require 'json'
require 'net/http'
require 'tempfile'
require 'timeout'

# The browser specs' own reveal-multiplex (multiplex-server/, the package the
# public Railway server runs), so a spec that logs in as host never broadcasts
# through the relay songs.josh.ch uses. The sessions' secrets come from the
# page itself, like on the live site. It listens on whichever port the OS
# gives it, like FileServer: two runs at once, in two checkouts (two
# sessions, each in its worktree), used to collide on a fixed one, and the
# second one's specs failed.
module MultiplexServer
  DIR             = File.expand_path('../../multiplex-server', __dir__)
  STARTUP_TIMEOUT = 10

  @mutex = Mutex.new

  # The fixture carries it, and is built before any spec starts the server:
  # asking for it starts the server, since only then is its port known
  def self.url
    start
    address
  end

  def self.address
    "http://127.0.0.1:#{@port}"
  end
  private_class_method :address

  def self.start
    @mutex.synchronize do
      return if @pid

      raise 'node not found — the browser specs need Node.js >= 18' \
        unless system('node', '--version', out: File::NULL, err: File::NULL)
      raise 'multiplex-server dependencies missing — run: npm install --prefix multiplex-server' \
        unless File.exist?(File.join(DIR, 'node_modules', 'reveal-multiplex', 'index.js'))

      # A file, not a pipe: the server logs every relayed event, and an
      # undrained pipe would block it once the buffer fills.
      @log = Tempfile.new('multiplex-server')
      # Where localhost.js writes the port it got
      @port_file = Tempfile.new('multiplex-port')
      @pid = Process.spawn({ 'PORT' => '0', 'PORT_FILE' => @port_file.path },
                           'node', '--require', './localhost.js', 'node_modules/reveal-multiplex/index.js',
                           chdir: DIR, out: @log.path, err: @log.path)
      at_exit { stop }
      await_ready
    end
  end

  def self.stop
    return unless @pid

    Process.kill('TERM', @pid)
    Process.wait(@pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil # already gone
  ensure
    @pid = nil
  end

  def self.await_ready
    Timeout.timeout(STARTUP_TIMEOUT) do
      loop do
        raise "multiplex-server died on startup:\n#{@log.read}" if Process.waitpid(@pid, Process::WNOHANG)

        port = File.read(@port_file.path).strip
        if port.empty?
          sleep 0.05
          next
        end
        @port = Integer(port)
        begin
          Net::HTTP.get(URI("#{address}/token"))
          return
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET
          sleep 0.05
        end
      end
    end
  rescue Timeout::Error
    raise "multiplex-server did not answer within #{STARTUP_TIMEOUT}s:\n#{@log.read}"
  end
  private_class_method :await_ready
end
