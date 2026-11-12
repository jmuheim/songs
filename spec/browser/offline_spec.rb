require 'capybara/rspec'

# The service worker (lib/service-worker.js, written as sw.js beside the
# page). Every other spec keeps it off (spec_helper.rb): its cache would
# outlast an example and serve the next one. Offline here is the file server
# stopped, not an emulated network, which needn't reach the worker: it fetches
# from a target of its own.
# The browser clients resume_service_workers has a handler on
SERVICE_WORKERS_RESUMED = {}.compare_by_identity

RSpec.describe 'offline (service worker)', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    MultiplexServer.start
    Capybara.app_host = FileServer.url
  end

  # Ferrum attaches to every new target with waitForDebuggerOnStart, and lets
  # go only of the types it knows (pages, iframes): a service worker stayed
  # paused, and its registration never settled. So this lets it run, once per
  # browser (a handler stays with the client across examples).
  def resume_service_workers
    client = page.driver.browser.client
    SERVICE_WORKERS_RESUMED[client] ||= client.on('Target.attachedToTarget') do |params|
      next unless params['targetInfo']['type'] == 'service_worker' && params['waitingForDebugger']

      client.session(params['sessionId']).command('Runtime.runIfWaitingForDebugger', async: true)
    end
  end

  before do
    resume_service_workers
    page.driver.browser.page.command('Page.addScriptToEvaluateOnNewDocument', source: 'window.SERVICE_WORKER_OFF = false;')
  end

  # Nothing of it is left for the examples that follow
  after do
    FileServer.start
    page.evaluate_async_script(<<~JS)
      var done = arguments[0];
      if (!navigator.serviceWorker) return done();
      navigator.serviceWorker.getRegistrations()
        .then(function(registrations) { return Promise.all(registrations.map(function(r) { return r.unregister(); })); })
        .then(function() { return caches.keys(); })
        .then(function(keys) { return Promise.all(keys.map(function(key) { return caches.delete(key); })); })
        .then(function() { done(); }, function() { done(); });
    JS
  end

  # Registered once the page has loaded, in control once it has kept every file
  def visit_controlled
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
    wait_for_js('!!navigator.serviceWorker.controller', timeout: 10)
    expect(page.evaluate_script('!!navigator.serviceWorker.controller')).to be true
  end

  # The Cache Storage is only reached by a promise, out of wait_for_js's reach
  def cache_names
    page.evaluate_async_script('caches.keys().then(arguments[0])')
  end

  it 'opens, reloads and takes a QR code from its cache, with the server gone' do
    visit_controlled
    FileServer.stop

    page.refresh
    wait_for_reveal
    expect(page).to have_css('section.deck-title-slide.present')
    # Every script came along, the relay's client included
    expect(page.evaluate_script("[typeof io, typeof sha256Hex, typeof QRCode, typeof tocFilter, typeof songWishes].join()"))
      .to eq('function,function,function,object,object')

    # A QR code scanned with no connection: the address is another one, the page the same
    visit "#{FixtureBuilder::URL_PATH}?live=spec-offline&qr=1"
    wait_for_reveal
    expect(page).to have_css('#qr-title', text: 'Du bist dabei!')
    expect(session_secret).to eq('spec-offline')
  end

  it 'shows a new build from the load after the one that finds it, and keeps nothing of the old' do
    visit_controlled
    expect(cache_names.size).to eq(1)

    old_page = File.read(FixtureBuilder::OUTPUT, encoding: 'UTF-8')
    old_worker = File.read(FixtureBuilder::SERVICE_WORKER, encoding: 'UTF-8')
    begin
      # The next build: another page, and so another sw.js
      at = old_page.rindex('</body>')
      File.write(FixtureBuilder::OUTPUT, old_page[0...at] + '<p id="next-build">neu</p>' + old_page[at..], encoding: 'UTF-8')
      File.write(FixtureBuilder::SERVICE_WORKER, old_worker.sub(/^const VERSION = '\h+';$/, "const VERSION = 'next';"), encoding: 'UTF-8')

      # This load is still the build it keeps, at once; it finds the new one
      page.refresh
      wait_for_reveal
      expect(page).to have_no_css('#next-build', visible: :all)
      deadline = Time.now + 10
      sleep 0.1 until cache_names == ['songs-next'] || Time.now > deadline
      expect(cache_names).to eq(['songs-next'])

      # The next is the new build
      page.refresh
      wait_for_reveal
      expect(page).to have_css('#next-build', visible: :all)
    ensure
      File.write(FixtureBuilder::OUTPUT, old_page, encoding: 'UTF-8')
      File.write(FixtureBuilder::SERVICE_WORKER, old_worker, encoding: 'UTF-8')
    end
  end
end
