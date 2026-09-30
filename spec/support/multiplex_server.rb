require 'digest'
require 'json'
require 'net/http'
require 'socket'
require 'tempfile'
require 'timeout'

# The browser specs' own reveal-multiplex (multiplex-server/, the package the
# public Railway server runs), so a spec that becomes master never broadcasts
# on the channel songs.josh.ch listens to. Port and token are fixed because
# the fixture carries them, and the committed fixture must stay the same run
# to run.
module MultiplexServer
  PORT            = 18_889
  DIR             = File.expand_path('../../multiplex-server', __dir__)
  SECRET          = 'songs-spec'
  SOCKET_ID       = Digest::SHA256.hexdigest(SECRET) # the server checks sha256(secret) == socketId
  STARTUP_TIMEOUT = 10

  @mutex = Mutex.new

  def self.url
    "http://127.0.0.1:#{PORT}"
  end

  def self.start
    @mutex.synchronize do
      return if @pid

      raise 'node not found — the browser specs need Node.js >= 18' \
        unless system('node', '--version', out: File::NULL, err: File::NULL)
      raise 'multiplex-server dependencies missing — run: npm install --prefix multiplex-server' \
        unless File.exist?(File.join(DIR, 'node_modules', 'reveal-multiplex', 'index.js'))
      # Otherwise ours dies on EADDRINUSE while the other one answers the
      # readiness check, and the specs quietly broadcast into whatever that is.
      raise "port #{PORT} is taken — is a multiplex server from a manual test still running?" if port_taken?

      # A file, not a pipe: the server logs every relayed event, and an
      # undrained pipe would block it once the buffer fills.
      @log = Tempfile.new('multiplex-server')
      @pid = Process.spawn({ 'PORT' => PORT.to_s },
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

  def self.port_taken?
    TCPSocket.new('127.0.0.1', PORT).close
    true
  rescue Errno::ECONNREFUSED
    false
  end
  private_class_method :port_taken?

  def self.await_ready
    Timeout.timeout(STARTUP_TIMEOUT) do
      loop do
        raise "multiplex-server died on startup:\n#{@log.read}" if Process.waitpid(@pid, Process::WNOHANG)

        begin
          Net::HTTP.get(URI("#{url}/token"))
          return
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET
          sleep 0.05
        end
      end
    end
  rescue Timeout::Error
    raise "multiplex-server did not answer on port #{PORT} within #{STARTUP_TIMEOUT}s:\n#{@log.read}"
  end
  private_class_method :await_ready
end
