require 'capybara/rspec'
require 'digest'

RSpec.describe 'index.html', :js, type: :feature do
  # The slides slide-zoom.js fits (its FITTED): every one but the TOC
  FITTED_CONTENT = 'section.deck-title-slide > .slide-content, section.level1 > .slide-content, section.level2 > .slide-content'.freeze

  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    MultiplexServer.start
    Capybara.app_host = FileServer.url
  end

  # Standard setup shared by most groups
  def load_presentation
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
  end

  def go_to_first_song
    # v=0 is the song's title slide, v=1 its "Infos über das Lied" (tags) slide;
    # the first slide that carries chords is v=2.
    page.evaluate_script("Reveal.slide(3, 2)")
    wait_for_js("Reveal.getIndices().h === 3 && Reveal.getIndices().v === 2")
  end

  def backdrop_click(id)
    page.execute_script("document.getElementById('#{id}').click()") # e.target must be the overlay, not a child
  end

  # 🚀, 🔗 and the host login sit in the live-scroll dialog behind 📡 (bottom left)
  def open_live_scroll_dialog
    # A toast that just appeared lifts the bottom corners clear of it over
    # 0.3s (night.css), and a click computed at the start of that slide lands
    # where 📡 used to be
    wait_for_js("document.getElementById('bottom-left-controls').getAnimations().length === 0")
    find('#multiplex-status-button').click
    expect(page).to have_visible('#multiplex-info-modal')
  end

  # The session this device is in: its secret, in its storage
  def session_secret
    page.evaluate_script("(JSON.parse(localStorage.getItem('multiplex-session')) || {}).secret || null")
  end

  # Joins a session by the address of the host's QR code, as scanning it does
  def join_session(secret)
    visit "#{FixtureBuilder::URL_PATH}?live=#{secret}"
    wait_for_reveal
  end

  # Logs in as host from the 📡 dialog: opens a session, or takes over the one
  # this tab is in. `label` is what the login button reads. The heartbeat is
  # shortened first, so whoever joins late and the end of a live scroll
  # arrive quickly. The password is asked only the first time on a device.
  def log_in_as_host(heartbeat: 200, label: 'Als Gastgeber anmelden')
    page.execute_script("window.MULTIPLEX.heartbeat = #{heartbeat}")
    open_live_scroll_dialog
    within('#multiplex-info-modal') { click_button("🔑 #{label}") }
    if page.has_css?('#host-modal[open]', wait: 0.5)
      within('#host-modal') do
        find('#host-pw').set(page.evaluate_script("window.MULTIPLEX.password"))
        click_button('Weiter')
      end
    end
    expect(page).to have_css('#host-login[hidden]', visible: :all)
  end

  # 🚀 starts or ends live scrolling; label is what it reads right now
  def press_live(label)
    open_live_scroll_dialog
    within('#multiplex-info-modal') { click_button("🚀 #{label}") }
  end

  # Picks who scrolls the current song. Host tabs.
  def start_live(mode:)
    press_live('Live-Scrollen starten')
    within('#scroll-choice-modal') do
      click_button(mode == :self ? 'Ich selber möchte scrollen' : 'Ein Gast soll scrollen')
    end
  end

  # A second socket (forceNew, so the relay sees it as another client) in this
  # tab's session that learns the live scroll's id from the host's own
  # heartbeat and then, on demand, volunteers under an id no real tab owns. The
  # named scroller therefore never sends any state — exactly the live moment
  # just after a guest takes over, its first state still crossing the network.
  # Real localhost tabs can't reproduce it: their state arrives in
  # milliseconds, before the release checker's next tick.
  def install_phantom_guest
    page.execute_script(<<~JS)
      window._phantom = { connected: false, liveId: null };
      var cfg = window.MULTIPLEX;
      var spy = io(cfg.url, { forceNew: true });
      spy.on('connect', function() { window._phantom.connected = true; });
      spy.on(cfg.socketId, function(data) {
        if (data && data.type === 'host' && data.live && data.live.mode === 'guest' && !data.live.scrollerId) {
          window._phantom.liveId = data.live.id;
        }
      });
      window._phantomVolunteer = function() {
        spy.emit('multiplex-statechanged', {
          type: 'volunteer', liveId: window._phantom.liveId, from: 'phantom-guest',
          secret: cfg.secret, socketId: cfg.socketId
        });
      };
      // Simulates the phantom guest resuming after a silence — a state
      // message is all it takes to refresh lastLiveAt on the receiving end.
      window._phantomState = function() {
        spy.emit('multiplex-statechanged', {
          type: 'state', liveId: window._phantom.liveId, state: { indexh: 4, indexv: 0 },
          from: 'phantom-guest', secret: cfg.secret, socketId: cfg.socketId
        });
      };
    JS
  end

  # A second socket (forceNew) in this tab's session that feeds it fabricated
  # `host` broadcasts, standing in for a host. Driving a real two-guest race
  # to test the *losing* side's feedback doesn't work: the relay resolves it in
  # milliseconds, well before a second real tab could still have its invite
  # open to lose from (see install_phantom_guest above for the same problem
  # from the host's side).
  def install_spy
    page.execute_script("window._spy = io(window.MULTIPLEX.url, { forceNew: true });")
    wait_for_js("window._spy.connected")
    expect(page.evaluate_script("window._spy.connected")).to be true
  end

  def spy_send_host(live, claim: 1, fresh: false)
    page.execute_script(<<~JS)
      window._spy.emit('multiplex-statechanged', Object.assign({
        type: 'host', claim: #{claim}, fresh: #{fresh}, live: #{live.to_json}
      }, { secret: window.MULTIPLEX.secret, socketId: window.MULTIPLEX.socketId, from: 'spy' }));
    JS
  end

  def tooltip_shown?(id)
    page.evaluate_script("getComputedStyle(document.querySelector('##{id} > .visually-hidden')).clipPath") == 'none'
  end

  def slide_indices
    page.evaluate_script("[Reveal.getIndices().h, Reveal.getIndices().v]")
  end

  # Simulate a touch swipe by (dx, dy) px across the current slide. Below
  # Capybara on purpose: a swipe has no Capybara action, and Cuprite's mouse
  # emits pointerType 'mouse', which both Reveal and the song-book's swipe guard
  # ignore. We drive the very events they listen to — pointer events with
  # pointerType 'touch' where the browser has them (Chrome does), touch events
  # otherwise.
  def swipe(dx:, dy:)
    page.execute_script(<<~JS, dx, dy)
      var dx = arguments[0], dy = arguments[1];
      var usePointer = ('onpointerdown' in window);
      var el = Reveal.getCurrentSlide();
      var r = el.getBoundingClientRect();
      var x0 = Math.round(r.left + r.width / 2), y0 = Math.round(r.top + r.height / 2);
      function fire(type, x, y) {
        el.dispatchEvent(new PointerEvent(type, { pointerId: 1, pointerType: 'touch',
          clientX: Math.round(x), clientY: Math.round(y), bubbles: true, cancelable: true }));
      }
      if (!usePointer) throw new Error('swipe helper assumes pointer events');
      fire('pointerdown', x0, y0);
      for (var i = 1; i <= 5; i++) fire('pointermove', x0 + dx * i / 5, y0 + dy * i / 5);
      fire('pointerup', x0 + dx, y0 + dy);
    JS
  end

  # -----------------------------------------------------------------------
  # Structure & initial state
  # -----------------------------------------------------------------------
  describe 'structure' do
    before { load_presentation }

    it 'has the correct DOM structure and initial state' do
      expect(page).to have_css('section.deck-title-slide.present')
      expect(page.evaluate_script("document.documentElement.lang")).to eq('de-CH')
      # One control per corner, nothing more
      expect(page).to have_css('.controls-group .ctrl', count: 4)
      within('#top-left-controls') { expect(page).to have_link('📖 Table of contents') }
      within('#top-right-controls') { expect(page).to have_button('↕️ Vollbild') }
      within('#bottom-left-controls') do
        expect(page).to have_css('#multiplex-status-button[aria-haspopup="dialog"]', text: '📡')
      end
      within('#bottom-right-controls') { expect(page).to have_button('⚙️ Settings') }
      # 🚀 and 🔗 sit in the 📡 dialog, out of sight until it opens
      expect(page).to have_css('#multiplex-info-modal #live-toggle', visible: :hidden)
      expect(page).to have_css('#multiplex-info-modal #show-qr', visible: :hidden)

      # In no session (nothing stored, no ?live= from a QR code): not even a socket is opened
      expect(page.evaluate_script("window.MULTIPLEX.socket === undefined")).to be true

      # Every device derives the relay channel from the session's secret, with
      # sha256.js. The relay only forwards when its own SHA-256 agrees, so it
      # must match Ruby's: across several blocks, and in UTF-8 too.
      ['songs-spec', 'x' * 56, 'Über den Wolken – 🎸' * 5].each do |text|
        expect(page.evaluate_script("sha256Hex(#{text.to_json})")).to eq(Digest::SHA256.hexdigest(text))
      end

      # title-slide + TOC + Introduction + fixture songs
      expect(all('.slides > section', visible: :all).size).to eq(3 + song_count)
    end

    it 'centers the title slide content vertically' do
      # section.deck-title-slide has no sub-slides, so it never gets wrapped in
      # a .stack — the flex rule that centers every other top-level section
      # vertically among its children does not apply to it, so it needs its own.
      rects = page.evaluate_script(<<~JS)
        (function() {
          var section = document.querySelector('section.deck-title-slide').getBoundingClientRect();
          var content = document.querySelector('section.deck-title-slide .slide-content').getBoundingClientRect();
          return [section.top, section.height, content.top, content.height];
        })();
      JS
      section_top, section_height, content_top, content_height = rects
      expect(content_top).to be_within(1).of(section_top + (section_height - content_height) / 2)
    end

    it 'puts the alternate fingerings on the Infos slide below its list, not beside it' do
      # The theme makes the <ul> inline-block and every sub-slide's content is
      # white-space: nowrap, so an inline-block <pre> sat on the list's line.
      # Only the fixture song with an Instructions section has a <pre> there.
      page.execute_script(<<~JS)
        var indices = Reveal.getIndices(document.querySelector('section[id^="infos-über-das-lied"] pre').closest('section'));
        Reveal.slide(indices.h, indices.v);
      JS
      expect(page).to have_css('section.present[id^="infos-über-das-lied"] > .slide-content[data-fitted] pre', visible: :all)
      # Which line each box sits on is a rendered position, out of Capybara's reach
      list_bottom, pre_top = page.evaluate_script(<<~JS)
        (function () {
          var content = document.querySelector('section.present.level2 > .slide-content');
          return [content.querySelector('ul').getBoundingClientRect().bottom,
                  content.querySelector('pre').getBoundingClientRect().top];
        })()
      JS
      expect(pre_top).to be >= list_bottom
    end
  end

  # -----------------------------------------------------------------------
  # Slide navigation
  # -----------------------------------------------------------------------
  describe 'slide navigation' do
    before { load_presentation }

    it 'responds to keyboard navigation horizontally and vertically' do
      find('body').send_keys(:right)
      expect(page).to have_css('#TOC.present')

      find('body').send_keys(:right)
      expect(page).to have_css('#introduction.present')

      find('body').send_keys(:down)
      expect(page).to have_css('section.present h2', text: 'Welcome')

      # Reveal writes the URL at most once a second; hiding the page (a phone
      # switching apps) writes it at once
      page.evaluate_script("Reveal.slide(3)")
      page.evaluate_script("Reveal.slide(4)")
      current = page.evaluate_script("'#' + Reveal.getSlidePath()")
      expect(page.evaluate_script("location.hash")).not_to eq(current) # else this proves nothing
      page.execute_script(<<~JS)
        Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
        document.dispatchEvent(new Event('visibilitychange'));
      JS
      expect(page.evaluate_script("location.hash")).to eq(current)
    end

    it 'keeps the title slide hash-free, adds one navigating off it, and drops it again coming back' do
      # Reveal debounces URL writes up to ~1s (see the comment above), so wait
      # for it rather than reading location.hash once — have_current_path
      # polls until Capybara.default_max_wait_time is exhausted.
      expect(page).to have_current_path(/\A[^#]*\z/, url: true)
      base_url = page.current_url
      # The title slide carries no id any more — see
      # decisions/2026-10-05-title-slide-id-replaced-with-a-class.md.
      expect(base_url).not_to include('#')

      find('body').send_keys(:right) # -> TOC, which does have an id
      expect(page).to have_current_path(%r{#/TOC\z}, url: true)

      find('body').send_keys(:left) # back to the id-less title slide
      expect(page).to have_current_path(Regexp.new("\\A#{Regexp.escape(base_url)}\\z"), url: true)
    end
  end

  # -----------------------------------------------------------------------
  # Reveal's chevrons (hidden on a touch screen: mobile_spec.rb)
  # -----------------------------------------------------------------------
  describe 'navigation chevrons' do
    # Loaded straight onto the Introduction, whose title is wide enough to
    # reach the screen edges.
    before do
      visit "#{FixtureBuilder::URL_PATH}#/introduction"
      wait_for_reveal
    end

    it 'shows them at the screen edges on a desktop, fits the slide between them, and pages the deck on a click' do
      expect(page).to have_css('.reveal .controls[data-controls-layout="edges"]')

      # The content sits between the side chevrons, not under them (to within
      # a pixel: the zoom is rounded to six digits; at full width it ran 44px in)
      gaps = page.evaluate_script(<<~JS)
        (function () {
          var content = Reveal.getCurrentSlide().querySelector('.slide-content').getBoundingClientRect();
          var prev = document.querySelector('.reveal .controls .navigate-left').getBoundingClientRect();
          var next = document.querySelector('.reveal .controls .navigate-right').getBoundingClientRect();
          return [content.left - prev.right, next.left - content.right];
        })()
      JS
      expect(gaps).to all(be > -1)

      # The down chevron pages on, and on a slide that fills the height
      # ("Basic chords") the content clears the up and down chevrons too
      2.times { |i| find('.reveal .controls .navigate-down').click; wait_for_js("Reveal.getIndices().v === #{i + 1}") }
      expect(slide_indices).to eq([2, 2])
      expect(page).to have_css('section.present.level2 > .slide-content[data-fitted]')
      gaps = page.evaluate_script(<<~JS)
        (function () {
          var content = Reveal.getCurrentSlide().querySelector('.slide-content').getBoundingClientRect();
          var up = document.querySelector('.reveal .controls .navigate-up').getBoundingClientRect();
          var down = document.querySelector('.reveal .controls .navigate-down').getBoundingClientRect();
          return [content.top - up.bottom, down.top - content.bottom];
        })()
      JS
      expect(gaps).to all(be > -1)

      find('.reveal .controls .navigate-right').click
      wait_for_js("Reveal.getIndices().h === 3")
      expect(slide_indices).to eq([3, 0])
    end
  end

  # -----------------------------------------------------------------------
  # Keyboard shortcuts
  # -----------------------------------------------------------------------
  describe 'keyboard shortcuts' do
    before { load_presentation }

    it 's key does not open the speaker notes popup' do
      page.execute_script("window._openCount = 0; window.open = function() { window._openCount++; }")
      find('body').send_keys('s')
      expect(page.evaluate_script("window._openCount")).to eq(0)
    end

    it 'sets display to flex' do
      expect(page.evaluate_script("Reveal.getConfig().display")).to eq('flex')
    end

    it 'loads no plugins' do
      expect(page.evaluate_script("Reveal.getConfig().plugins")).to eq([])
    end
  end

  # -----------------------------------------------------------------------
  # Slide zoom (style/slide-zoom.js)
  # -----------------------------------------------------------------------
  describe 'slide zoom' do
    before { load_presentation }

    # How far the widest line of the current slide's title stops short of each
    # screen edge, less the content's own padding at the scale it is shown at:
    # [0, 0] for a title that fills the width. Measured on the text's own line
    # boxes (a Range): a wrapped title's box spans the full width either way.
    TITLE_FILL = <<~JS.freeze
      (function () {
        var content = Reveal.getCurrentSlide().querySelector('.slide-content');
        var range = document.createRange(), left = Infinity, right = -Infinity, lines = 0;
        Array.prototype.forEach.call(content.children, function (child) {
          range.selectNodeContents(child);
          Array.prototype.forEach.call(range.getClientRects(), function (r) {
            lines++; left = Math.min(left, r.left); right = Math.max(right, r.right);
          });
        });
        var padding = parseFloat(getComputedStyle(content).paddingLeft) *
                      content.getBoundingClientRect().width / content.offsetWidth;
        return { wrapped: lines > content.children.length,
                 shortfall: [left - padding, innerWidth - right - padding] };
      })()
    JS

    def expect_wrapped_title_to_fill_the_width
      # The slide is fitted in a frame of its own after it appears; wait for it
      wait_for_js("#{TITLE_FILL}.shortfall.every(function (s) { return Math.abs(s) < 1; })")
      fill = page.evaluate_script(TITLE_FILL)
      expect(fill['wrapped']).to be(true) # else this proves nothing
      expect(fill['shortfall']).to all(be_within(1).of(0))
    end

    # The lines the current slide's heading is set on
    HEADING_LINES = <<~JS.freeze
      (function () {
        var range = document.createRange();
        range.selectNodeContents(Reveal.getCurrentSlide().querySelector('h1'));
        return range.getClientRects().length;
      })()
    JS

    it 'fits the slide on slide change and again on window resize, and a wrapped title by its widest line' do
      # A title that changes its wrapping changes its size after the observer
      # reported it; slide-zoom.js must not let the observer report it again
      # in the same frame ("ResizeObserver loop completed with undelivered
      # notifications"). Cuprite doesn't fail on page errors, so collect them.
      page.execute_script("window._errors = []; window.addEventListener('error', function (e) { window._errors.push(e.message); })")

      # The verse and clamp values are exact on every platform (both are pure
      # text — the fonts are bundled, so they render identically). The title
      # slide carries emoji, which Chrome lays out differently across its own
      # builds (see decisions/2026-09-30-emoji-zoom-is-not-reproducible-across-
      # chrome-builds.md); its exact scale therefore only holds locally, so on the
      # CI runner we assert only that the title is zoomed up to fill. The floor
      # sits at 1.1, well clear of 1 (no zoom, or the old stretch cap): fitted
      # between the desktop chevrons on one line, the runner's title came out
      # at 1.24. Wrapped over two lines, as it is here, it comes out at 2.3, and
      # the ceiling leaves room for the emoji to set those lines a little
      # differently.
      if ENV['CI']
        expect(page).to have_css('section.deck-title-slide .slide-content[data-fitted]', visible: :all)
        title_scale = page.evaluate_script("parseFloat(document.querySelector('section.deck-title-slide .slide-content').style.transform.replace('scale(', ''))")
        expect(title_scale).to be_between(1.1, 3)
      else
        expect(page).to have_css('section.deck-title-slide .slide-content[style="transform: scale(2.29866);"]', visible: :all)
      end

      page.evaluate_script("Reveal.slide(2, 1)")
      expect(page).to have_css('section.present.level2 .slide-content[style="transform: scale(0.710793);"]', visible: :all)

      # A song's slide ends on a preview of the next one's first line
      # (.next-line), fitted along with the lyrics. It never wraps, like the
      # lyrics: on the first song's Intro (four chords) its preview of a whole
      # line of Verse 1 is the widest thing on the slide, and the slide is
      # fitted to it, not cut off at the chords' width
      page.evaluate_script("Reveal.slide(3, 2)")
      expect(page).to have_css('section.present.level2 > .slide-content[data-fitted] .next-line', visible: :all)
      preview_lines, preview_overflow, widest = page.evaluate_script(<<~JS)
        (function () {
          var content = Reveal.getCurrentSlide().querySelector('.slide-content');
          var preview = content.querySelector('.next-line');
          var style = getComputedStyle(preview);
          // The text's own width, not its block's (which spans the slide)
          var textWidth = function (el) {
            var range = document.createRange();
            range.selectNodeContents(el);
            return range.getBoundingClientRect().width;
          };
          return [(preview.clientHeight - parseFloat(style.paddingTop)) / parseFloat(style.lineHeight),
                  preview.scrollWidth - preview.clientWidth,
                  textWidth(content.querySelector('p:not(.next-line)')) < textWidth(preview)];
        })()
      JS
      expect(preview_lines).to be_within(0.1).of(1)
      expect(preview_overflow).to eq(0)
      expect(widest).to be true

      # A song's title takes as many lines as make it largest. Here, that's
      # three: on one line, it filled the width at scale(1.26673) and left most
      # of the height empty.
      page.evaluate_script("Reveal.slide(6, 0)") # Imagine (John Lennon)
      expect(page).to have_css('section.present.level1 .slide-content[style="transform: scale(2.29221);"]', visible: :all)
      expect(page.evaluate_script(HEADING_LINES)).to eq(3)

      page.evaluate_script("Reveal.slide(0, 0)")
      page.driver.browser.resize(width: 480, height: 600)
      page.evaluate_script("window.dispatchEvent(new Event('resize'))") # Cuprite's resize doesn't fire the browser event
      # Below 500px the chevrons are hidden (reveal.css has no edges layout
      # there), so the title gets the whole width again
      expect(page).to have_css('.reveal .controls', visible: :hidden)
      # Too long for one line at this width, the title wraps. Its box spans
      # the width while its lines don't, so it is fitted by its widest line,
      # which reaches the screen edges. Measured by the box, it stayed at
      # scale(1), its lines short of the edges (a song's title on an iPad in
      # portrait). The deck's own title, then a song's.
      expect_wrapped_title_to_fill_the_width
      page.evaluate_script("Reveal.slide(3, 0)") # 74-75 (The Connells)
      expect_wrapped_title_to_fill_the_width

      # On a screen as wide and short as a phone held sideways, the same title
      # takes two: a third line would cost more height than it saves width
      page.evaluate_script("Reveal.slide(6, 0)") # Imagine (John Lennon)
      page.driver.browser.resize(width: 844, height: 390)
      page.evaluate_script("window.dispatchEvent(new Event('resize'))")
      expect(page).to have_css('section.present.level1 .slide-content[style="transform: scale(1.2772);"]', visible: :all)
      expect(page.evaluate_script(HEADING_LINES)).to eq(2)

      expect(page.evaluate_script('window._errors')).to eq([])
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end

    it 'fits every slide the overview shows, and the slide picked there as on a direct visit' do
      press(:escape) # Reveal's overview
      expect(page).to have_css('.reveal.overview')
      # The slides the overview reveals are fitted in the next frame, before
      # it paints; this check would otherwise run before that frame
      shown_and_unfitted = <<~JS
        (function () {
          var shown = Array.prototype.filter.call(document.querySelectorAll('#{FITTED_CONTENT}'),
                                                  function (c) { return c.offsetWidth; });
          return [shown.length, shown.filter(function (c) { return !c.hasAttribute('data-fitted'); }).length];
        })()
      JS
      wait_for_js("#{shown_and_unfitted}[1] === 0")
      shown, unfitted = page.evaluate_script(shown_and_unfitted)
      expect(shown).to be > 20 # far more than the current slide and its neighbours
      expect(unfitted).to eq(0)
      # The overview gives each slide the full screen height; the Introduction
      # still gets its own fit, not one capped at 1 by measuring that height
      expect(page).to have_css('#introduction > .slide-content[style="transform: scale(2.30108);"]', visible: :all)

      press(:right, :right, :down, :enter) # pick "Welcome" (2, 1)
      expect(page).to have_no_css('.reveal.overview')
      expect(slide_indices).to eq([2, 1])
      expect(page).to have_css('section.present.level2 .slide-content[style="transform: scale(0.710793);"]', visible: :all)
    end
  end

  # -----------------------------------------------------------------------
  # Next-line preview (inject_next_line_previews; its fade in shared.css)
  # -----------------------------------------------------------------------
  describe 'next-line preview' do
    before { load_presentation }

    it 'is transparent as its slide is shown and fades in slowly later, stays put while its slide leaves, starts over on every visit, and shows at once for a focused chord or the end of the song' do
      # Imagine's Verse 1, whose preview is the Bridge's first line. Not yet
      # rendered (display: none, beyond Reveal's view distance): the jump
      # there shows it with no earlier opacity to fade from (@starting-style)
      verse = 'Reveal.getSlide(6, 3)'
      preview = "#{verse}.querySelector('.next-line')"
      fade = <<~JS
        (function () {
          var preview = #{preview}, transition = preview.getAnimations()[0];
          return [getComputedStyle(preview).opacity, transition && transition.transitionProperty,
                  transition && transition.effect.getTiming().delay, transition && transition.effect.getTiming().duration];
        })()
      JS
      expect(page.evaluate_script("getComputedStyle(#{verse}).display")).to eq('none')
      page.evaluate_script("Reveal.slide(6, 3)")
      wait_for_js("Reveal.getIndices().v === 3")
      # Transparent, and a few seconds later it fades in slowly, up to 60%:
      # it keeps the lyrics' own colours (its heading the slide title's), its
      # opacity alone dims it
      expect(page.evaluate_script(fade)).to eq(['0', 'opacity', 3000, 3000])
      finish_next_line_fade
      expect(page.evaluate_script("getComputedStyle(#{preview}).opacity")).to eq('0.6')
      colour = ->(el) { page.evaluate_script("getComputedStyle(#{el}).color") }
      expect(colour.(preview)).to eq(colour.("#{verse}.querySelector('p:not(.next-line)')"))
      expect(colour.("#{preview}.querySelector('.next-line-section')")).to eq(colour.("#{verse}.querySelector('h2')"))

      # Leaving, it keeps what it showed while Reveal moves the slide out
      # (0.8s), rather than snapping away; only then is it reset
      page.evaluate_script("Reveal.slide(6, 4)")
      wait_for_js("Reveal.getIndices().v === 4")
      expect(page.evaluate_script(fade)).to eq(['0.6', 'opacity', 800, 0])
      wait_for_js("getComputedStyle(#{preview}).opacity === '0'")
      expect(page.evaluate_script("getComputedStyle(#{preview}).opacity")).to eq('0')

      # Back on it, it starts over
      page.evaluate_script("Reveal.slide(6, 3)")
      wait_for_js("Reveal.getIndices().v === 3")
      expect(page.evaluate_script(fade)).to eq(['0', 'opacity', 3000, 3000])

      # A chord in it that takes the focus shows it at once, mid-wait
      page.execute_script("#{preview}.querySelector('button.chord').focus()")
      expect(page.evaluate_script("getComputedStyle(#{preview}).opacity")).to eq('0.6')

      # „Ende des Lieds" on the song's last slide has nothing to read ahead:
      # it is there at once, with no wait and no fade
      last = "Reveal.getSlide(6).querySelector('.next-line-end')"
      page.evaluate_script("Reveal.slide(6, Reveal.getIndices(#{last}.closest('section.slide')).v)")
      wait_for_js("Reveal.getCurrentSlide().contains(#{last})")
      expect(page.evaluate_script("[getComputedStyle(#{last}).opacity, #{last}.getAnimations().length]")).to eq(['0.6', 0])
    end
  end

  describe 'slide zoom, on load' do
    it 'never shows a slide before it is fitted, and shows it anyway should the fit never come' do
      # What each animation frame finds on the current slide, sampled from
      # before the page's own scripts run. A frame's sample is taken before its
      # ResizeObserver callbacks (the fit), so a slide Reveal shows unfitted
      # for a single frame would be caught here.
      page.driver.browser.page.command('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
        window._frames = [];
        (function sample() {
          var section = document.querySelector('.reveal .slides section.present > section.present') ||
                        document.querySelector('.reveal .slides > section.present');
          var content = section && section.querySelector('.slide-content');
          if (content && getComputedStyle(content).visibility === 'visible') {
            window._frames.push(content.hasAttribute('data-fitted') ? 'fitted' : 'unfitted');
          }
          if (window._frames.length < 30) requestAnimationFrame(sample);
        })();
      JS
      visit "#{FixtureBuilder::URL_PATH}#/2/1"
      wait_for_reveal
      wait_for_js('window._frames.length >= 30')
      frames = page.evaluate_script('window._frames')
      expect(frames.length).to eq(30)
      expect(frames).to all(eq('fitted'))

      # The script failed to load, say: the content shows unfitted after a
      # second, rather than staying invisible
      page.execute_script("Reveal.getCurrentSlide().querySelector('.slide-content').removeAttribute('data-fitted')")
      expect(page).to have_css('section.present.level2 > .slide-content', visible: :hidden)
      expect(page).to have_css('section.present.level2 > .slide-content:not([data-fitted])', visible: true)
    end
  end

  # -----------------------------------------------------------------------
  # TOC navigation
  # -----------------------------------------------------------------------
  describe 'TOC navigation' do
    before { load_presentation }

    it 'has correct structure and navigates on click' do
      expect(page).to have_css('#go-to-toc[href="#/1"]')
      # The Introduction isn't a song and isn't listed.
      expect(all('#TOC a', visible: :all).size).to eq(song_count)

      # By Reveal's jump, not by following the link: a navigation leaves an
      # entry in the history, and makes an iPhone's Safari show its bars again
      history_length = page.evaluate_script('history.length')
      click_link('Table of contents')
      expect(page).to have_css('#TOC.present')
      expect(page.evaluate_script('history.length')).to eq(history_length)

      click_link 'Imagine (John Lennon)'
      expect(page).to have_css('#imagine-john-lennon.present')
    end
  end

  # -----------------------------------------------------------------------
  # Chord visibility toggle
  # -----------------------------------------------------------------------
  describe 'chord visibility toggle' do
    before do
      load_presentation
      go_to_first_song
      finish_next_line_fade # its chords count among the slide's visible ones
      click_button('⚙️ Settings')
    end

    it 'toggles chord visibility from the settings dialog, and fits the slide again' do
      fitted = 'section.slide.present > .slide-content[style="transform: scale(1.8088);"]'
      expect(page).to have_css(fitted, visible: :all)
      expect(page).to have_no_css('body.chords-hidden')
      within 'section.slide.present' do
        expect(page).to have_css('code')
        expect(page).to have_no_css('code', visible: :hidden)
      end
      expect(page).to have_checked_field('Akkorde anzeigen')

      uncheck('Akkorde anzeigen')
      expect(page).to have_css('body.chords-hidden')
      within 'section.slide.present' do
        expect(page).to have_css('code', visible: :hidden)
        expect(page).to have_no_css('code')
        # The chord's button goes with its pill: an empty one would still be
        # a Tab stop
        expect(page).to have_no_css('button.chord')
      end
      # Without its chords the slide's content is smaller, and fitted anew
      expect(page).to have_no_css(fitted, visible: :all)
      expect(page).to have_css('section.slide.present > .slide-content[style^="transform: scale("]', visible: :all)

      check('Akkorde anzeigen')
      expect(page).to have_no_css('body.chords-hidden')
      within 'section.slide.present' do
        expect(page).to have_css('code')
        expect(page).to have_no_css('code', visible: :hidden)
      end
      expect(page).to have_css(fitted, visible: :all)

      # check() leaves the checkbox itself focused (it's what was clicked). The
      # dialog stops a keydown before it ever reaches Reveal, so — unlike a
      # .ctrl button sitting directly on the slide — there's no page-turn race
      # to guard against here: Space just toggles the still-focused checkbox.
      before = slide_indices
      press(:space)
      expect(page).to have_css('body.chords-hidden')
      expect(slide_indices).to eq(before)
    end
  end

  # -----------------------------------------------------------------------
  # Theme toggle
  # -----------------------------------------------------------------------
  describe 'theme toggle' do
    def body_background_color
      page.evaluate_script("getComputedStyle(document.body).getPropertyValue('--r-background-color').trim()")
    end

    before { load_presentation }
    after { page.evaluate_script("localStorage.removeItem('theme')") }

    it 'switches theme from the settings dialog, persists preference, and restores on reload' do
      expect(page).to have_no_css('body.theme-bright')
      expect(body_background_color).to eq('#111')

      click_button('⚙️ Settings')
      expect(page).to have_select('theme-select', selected: 'Dunkel')

      select('Hell', from: 'theme-select')
      expect(page).to have_css('body.theme-bright')
      expect(body_background_color).to eq('#fffad5')
      expect(page.evaluate_script("localStorage.getItem('theme')")).to eq('bright')

      load_presentation
      expect(page).to have_css('body.theme-bright')

      click_button('⚙️ Settings')
      expect(page).to have_select('theme-select', selected: 'Hell')
      select('Dunkel', from: 'theme-select')
      expect(page).to have_no_css('body.theme-bright')
      expect(page.evaluate_script("localStorage.getItem('theme')")).to eq('dark')

      # With site data blocked, touching storage throws: the theme switches all the same
      using_session(:no_storage) do
        page.driver.browser.page.command('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
          ['localStorage', 'sessionStorage'].forEach(function (name) {
            Object.defineProperty(window, name, { get: function () { throw new DOMException('blocked', 'SecurityError'); } });
          });
        JS
        load_presentation
        expect { page.evaluate_script('localStorage') }.to raise_error(Ferrum::JavaScriptError)
        click_button('⚙️ Settings')
        select('Hell', from: 'theme-select')
        expect(page).to have_css('body.theme-bright')
      end
    end
  end

  # -----------------------------------------------------------------------
  # Settings dialog
  # -----------------------------------------------------------------------
  describe 'settings dialog' do
    before { load_presentation }

    it 'keeps the keys to itself, and closes on Esc, close button and outside click' do
      expect(page).not_to have_visible('#settings-modal')
      expect(page).to have_css('#open-settings[aria-haspopup="dialog"]')

      click_button('⚙️ Settings')
      expect(page).to have_visible('#settings-modal')
      expect(active_element_id).to eq('settings-title')

      # Reveal listens on the document: nothing pressed inside the dialog reaches it
      before = slide_indices
      press(:right)
      expect(slide_indices).to eq(before)
      press(:escape)
      expect(page).not_to have_visible('#settings-modal')
      expect(page.evaluate_script("Reveal.isOverview()")).to be false
      expect(active_element_id).to eq('open-settings')

      click_button('⚙️ Settings')
      click_button('Schliessen')
      expect(page).not_to have_visible('#settings-modal')

      click_button('⚙️ Settings')
      expect(page).to have_visible('#settings-modal')
      backdrop_click('settings-modal')
      expect(page).not_to have_visible('#settings-modal')
    end
  end

  # -----------------------------------------------------------------------
  # Vollbild (↕️)
  # -----------------------------------------------------------------------
  describe 'Vollbild' do
    def toggle_pressed
      find('#fullscreen-toggle')['aria-pressed']
    end

    def current_scale
      page.evaluate_script("Reveal.getCurrentSlide().querySelector('.slide-content').style.transform")
    end

    # How far +selector+'s bottom edge sits above the window's
    def bottom_gap(selector)
      page.evaluate_script("innerHeight - document.querySelector(#{selector.to_json}).getBoundingClientRect().bottom")
    end

    # A finger dragged +dy+ px down (negative: up) from the middle of +selector+.
    # Unlike `swipe`, real touches through Chrome's input pipeline (CDP), since
    # what's under test is whether the browser scrolls the page.
    def finger_swipe(selector, dy)
      x, y = page.evaluate_script(<<~JS)
        (function(r) { return [r.left + r.width / 2, r.top + r.height / 2]; })(document.querySelector(#{selector.to_json}).getBoundingClientRect())
      JS
      cdp = page.driver.browser.page
      cdp.command('Input.dispatchTouchEvent', type: 'touchStart', touchPoints: [{ x: x, y: y }])
      (1..10).each { |i| cdp.command('Input.dispatchTouchEvent', type: 'touchMove', touchPoints: [{ x: x, y: y + dy * i / 10.0 }]) }
      cdp.command('Input.dispatchTouchEvent', type: 'touchEnd', touchPoints: [])
    end

    it 'uses the Fullscreen API where there is one, and leaves it again on a second press' do
      load_presentation
      expect(toggle_pressed).to eq('false')

      click_button('↕️ Vollbild')
      wait_for_js('document.fullscreenElement === document.documentElement')
      expect(page.evaluate_script('document.fullscreenElement === document.documentElement')).to be true
      expect(toggle_pressed).to eq('true')
      expect(page).to have_css('#fullscreen-runway', visible: :hidden) # that one is for the iPhone

      click_button('↕️ Vollbild')
      wait_for_js('!document.fullscreenElement')
      expect(page.evaluate_script('document.fullscreenElement')).to be_nil
      expect(toggle_pressed).to eq('false')
    ensure
      page.execute_script('if (document.fullscreenElement) document.exitFullscreen()')
    end

    it "on an iPhone, lends the page a runway to swipe Safari's bars away, keeps them away while the deck pages, and gives the room back on a second press" do
      # ?runway: as on an iPhone, which has no Fullscreen API for a page. Basic
      # chords (2, 2) is fitted by its height, so it grows with the room.
      visit "#{FixtureBuilder::URL_PATH}?runway#/2/2"
      wait_for_reveal
      # Safari's vh never follows its bars, so the runway's height stays put as
      # they go, while in Chrome it would grow with the window. Pinned in px,
      # only the deck, pinned to the screen, changes size, as on the iPhone.
      page.execute_script(<<~JS)
        var style = document.createElement('style');
        style.textContent = '.runway-step { min-height: 800px } #fullscreen-runway { padding-bottom: 8000px }';
        document.head.appendChild(style);
      JS
      gear_gap = bottom_gap('#open-settings')

      # Like a dialog: it starts at its title, keeps the keys from Reveal, and
      # Esc closes it without opening the overview
      click_button('↕️ Vollbild')
      expect(page).to have_visible('#fullscreen-runway')
      expect(active_element_id).to eq('runway-title')
      expect(page).not_to have_visible('.runway-tip') # only once the bars are gone
      press(:right)
      expect(slide_indices).to eq([2, 2])
      press(:escape)
      expect(page).not_to have_visible('#fullscreen-runway')
      expect(page.evaluate_script('Reveal.isOverview()')).to be false
      expect(page.evaluate_script("document.documentElement.classList.contains('fullscreen-runway')")).to be false

      # Open, the page itself scrolls, while the deck stays pinned to the screen
      click_button('↕️ Vollbild')
      expect(page).to have_visible('#fullscreen-runway')
      expect(page.evaluate_script('document.scrollingElement.scrollHeight > innerHeight * 5')).to be true
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.reveal')).position")).to eq('fixed')
      fitted_with_bars = current_scale
      page.scroll_to(0, 300) # the finger's swipe down

      # Safari's bars going away make the window taller. Chrome has none, so a
      # taller window stands in for them; Cuprite's resize doesn't fire the
      # browser's event (see 'slide zoom').
      page.driver.browser.resize(width: 1280, height: 880)
      page.execute_script("window.dispatchEvent(new Event('resize'))")
      # It says so, and waits for OK; Esc would do the same
      expect(page).to have_css('#runway-success-text', text: 'Gut gemacht!')
      expect(active_element_id).to eq('runway-success-text')
      # Then the alternative, with a picture of Safari's menu: post_process_index
      # gave its src the assets path the page is served with, so it loads
      expect(page).to have_css('.runway-tip', text: 'Teilen → Zum Home-Bildschirm')
      expect(page).to have_css('img.runway-tip-image[src="/style/zum-home-bildschirm.png"]')
      wait_for_js("document.querySelector('.runway-tip-image').complete")
      expect(page.evaluate_script("document.querySelector('.runway-tip-image').naturalWidth")).to eq(598)
      expect(toggle_pressed).to eq('true')
      expect(page).to have_no_css('#fullscreen-runway.runway-done', visible: :all)
      click_button('OK')
      expect(page).to have_css('#fullscreen-runway.runway-done', visible: :hidden)
      expect(page).not_to have_visible('#runway-ok')
      # The runway keeps its room: a page back to one screen would scroll to
      # the top, which brings Safari's bars right back
      expect(page.evaluate_script('scrollY')).to eq(300)
      # The bottom corners rose out of the strip Safari's bottom bar left
      # behind, where a tap brings the bars back: by as much as the window grew
      expect(bottom_gap('#open-settings')).to be_within(0.5).of(gear_gap + 80)
      # The deck grew with the room, and fitted its slide to it, though <html> didn't
      wait_for_js("Reveal.getCurrentSlide().querySelector('.slide-content').style.transform !== #{fitted_with_bars.to_json}")
      expect(current_scale).not_to eq(fitted_with_bars)

      # Nor does a finger scroll the page, where .reveal's touch-action doesn't
      # reach: a corner button beside the deck, or a code block (overflow: auto,
      # a scroll container of its own). A swipe down there scrolled the page up,
      # and Safari brings its bars back on that. On the code block, Reveal pages
      # instead, as anywhere else on the slide.
      finger_swipe('#open-settings', 200)
      finger_swipe('section.present pre code', 200)
      wait_for_js('Reveal.getIndices().v === 1')
      expect(slide_indices).to eq([2, 1])
      expect(page.evaluate_script('scrollY')).to eq(300)

      # The deck pages as ever, and its keys don't scroll the page
      page.driver.browser.mouse.move(x: 640, y: 500)
      press(:up)
      expect(slide_indices).to eq([2, 0])
      expect(page.evaluate_script('scrollY')).to eq(300)

      # The table of contents still scrolls under a finger, but at its top a
      # swipe down doesn't pass on to the page. Padded, so the fixture's few
      # songs reach past the screen.
      page.execute_script("Reveal.slide(1); document.querySelector('#TOC nav ol').style.paddingBottom = '2000px'")
      expect(page).to have_css('#TOC.present')
      finger_swipe('#TOC nav li a', 200)
      finger_swipe('#TOC nav li a', -200)
      wait_for_js("document.getElementById('TOC').scrollTop > 0")
      expect(page.evaluate_script("document.getElementById('TOC').scrollTop")).to be > 0
      expect(page.evaluate_script('scrollY')).to eq(300)

      # A second press gives the room back
      click_button('↕️ Vollbild')
      expect(toggle_pressed).to eq('false')
      expect(page.evaluate_script("document.documentElement.classList.contains('fullscreen-runway')")).to be false
      expect(page.evaluate_script('scrollY')).to eq(0)
      expect(page).not_to have_visible('#fullscreen-runway')
      expect(bottom_gap('#open-settings')).to be_within(0.5).of(gear_gap)
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end

    it 'stays out of the way when the song book runs from the home screen, without any bars to hide' do
      # Below Capybara: iOS sets navigator.standalone before any script runs
      page.driver.browser.page.command('Page.addScriptToEvaluateOnNewDocument',
                                       source: "Object.defineProperty(navigator, 'standalone', { value: true });")
      load_presentation
      expect(page).to have_button('⚙️ Settings')
      expect(page).to have_css('#fullscreen-toggle', visible: :hidden)
    end
  end

  # -----------------------------------------------------------------------
  # Multiplex
  # -----------------------------------------------------------------------
  describe 'multiplex' do
    describe 'logging in as host' do
      before { load_presentation }

      it 'the password makes this device host of a new session, kept in its storage across a reload, until 🏁' do
        open_live_scroll_dialog
        within('#multiplex-info-modal') do
          expect(page).to have_css('#multiplex-info-status', text: 'Keine Session')
          expect(page).to have_css('#multiplex-info-join', text: 'Scanne den QR-Code eines Gastgebers')
          # A plain visitor has nothing to start, show or end
          expect(page).to have_no_button('🚀 Live-Scrollen starten', disabled: :all)
          expect(page).to have_no_button('🔗 QR-Code zeigen')
          expect(page).to have_no_button('🏁 Session beenden')
          click_button('🔑 Als Gastgeber anmelden')
        end
        expect(page).to have_visible('#host-modal')
        expect(page).to have_css('#host-title', text: 'Als Gastgeber anmelden')
        expect(active_element_id).to eq('host-pw')
        backdrop_click('host-modal')
        expect(page).not_to have_visible('#host-modal')

        open_live_scroll_dialog
        within('#multiplex-info-modal') { click_button('🔑 Als Gastgeber anmelden') }
        within('#host-modal') do
          find('#host-pw').set('something')
          click_button('Abbrechen')
        end
        expect(page).not_to have_visible('#host-modal')
        expect(page.evaluate_script("document.getElementById('host-pw').value")).to be_empty

        open_live_scroll_dialog
        within('#multiplex-info-modal') { click_button('🔑 Als Gastgeber anmelden') }
        within('#host-modal') do
          find('#host-pw').set('wrongpassword')
          click_button('Weiter')
          expect(page).to have_css('#host-pw.shake')
          expect(page.evaluate_script("document.getElementById('host-pw').value")).to be_empty
        end
        expect(page).to have_visible('#host-modal')
        expect(session_secret).to be_nil # no session for a wrong password

        within('#host-modal') do
          find('#host-pw').set(page.evaluate_script("window.MULTIPLEX.password"))
          click_button('Weiter')
        end
        expect(page).not_to have_visible('#host-modal')
        expect(page).to have_css('#multiplex-toast.visible', text: 'Du bist jetzt Gastgeber')
        expect(page).to have_css('#multiplex-status', text: 'Du bist Gastgeber')
        # A fresh secret, generated here, is the session — kept on the device,
        # not in the address, and hashed into the relay channel
        secret = session_secret
        expect(secret).to match(/\A\h{32}\z/)
        expect(page.evaluate_script("window.MULTIPLEX.socketId")).to eq(Digest::SHA256.hexdigest(secret))
        expect(page.evaluate_script("location.search")).to eq('')
        open_live_scroll_dialog
        within('#multiplex-info-modal') do
          expect(page).to have_button('🚀 Live-Scrollen starten', disabled: true) # the title slide is no song
          expect(page).to have_button('🔗 QR-Code zeigen')
          expect(page).to have_button('🏁 Session beenden')
          expect(page).to have_no_css('#multiplex-info-join', visible: true)
          expect(page).to have_no_button('🔑 Als Gastgeber anmelden')
        end
        press(:escape)

        # A reload keeps the session and the role
        page.refresh
        wait_for_reveal
        expect(session_secret).to eq(secret)
        expect(page).to have_css('#multiplex-status', text: 'Du bist Gastgeber')

        # 🏁 leaves the session: the device forgets it, and with it what only a session offers
        open_live_scroll_dialog
        within('#multiplex-info-modal') { click_button('🏁 Session beenden') }
        expect(page).to have_css('#multiplex-toast.visible', text: 'Die Session ist beendet')
        expect(page).to have_css('#multiplex-status', text: 'Keine Session')
        expect(session_secret).to be_nil
        open_live_scroll_dialog
        within('#multiplex-info-modal') { expect(page).to have_no_button('🔗 QR-Code zeigen') }
        press(:escape)

        # The password is asked once per device: the next login opens a new session straight away
        open_live_scroll_dialog
        within('#multiplex-info-modal') { click_button('🔑 Als Gastgeber anmelden') }
        expect(page).to have_css('#multiplex-status', text: 'Du bist Gastgeber')
        expect(page).not_to have_visible('#host-modal')
        expect(session_secret).to match(/\A\h{32}\z/)
        expect(session_secret).not_to eq(secret)
      end
    end

    describe '🚀 on a song only' do
      before do
        load_presentation
        log_in_as_host
      end

      it 'enables 🚀 only on a song — disabled, with the hint saying why, on the title, the TOC and the introduction' do
        live_disabled_at = lambda do |h|
          page.evaluate_script("Reveal.slide(#{h}, 0)")
          wait_for_js("Reveal.getIndices().h === #{h}")
          page.evaluate_script("document.getElementById('live-toggle').disabled")
        end

        wait_for_js("document.getElementById('live-toggle').disabled === true") # title slide on load
        open_live_scroll_dialog
        within('#multiplex-info-modal') do
          expect(page).to have_button('🚀 Live-Scrollen starten', disabled: true)
          expect(page).to have_css('#live-toggle-hint', text: 'nur auf einem Lied')
        end
        press(:escape)
        expect(live_disabled_at.call(1)).to be true  # TOC
        expect(live_disabled_at.call(2)).to be true  # Introduction (a stack; its slug sits on the first sub-slide)
        expect(live_disabled_at.call(3)).to be false # the first song
        open_live_scroll_dialog
        expect(page).to have_no_css('#live-toggle-hint', visible: true)
        press(:escape)
        expect(live_disabled_at.call(1)).to be true  # back off a song
      end
    end

    describe 'live sync' do
      after { Capybara.reset_sessions! }

      it 'self-scroll: the room is snapped and locked, vertical moves propagate, the song is a wall, ending frees everyone' do
        secret = nil
        using_session(:presenter) do
          load_presentation
          log_in_as_host
          secret = session_secret
        end

        using_session(:client) do
          join_session(secret)
          expect(page).to have_css('section.deck-title-slide.present')
          expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv') # connected
        end

        using_session(:presenter) do
          page.evaluate_script("Reveal.slide(3, 0)") # the first song
          wait_for_js("Reveal.getIndices().h === 3")
          start_live(mode: :self)
          expect(page).to have_css('#live-toggle.live-active', text: /🚀\s+Live-Scrollen beenden/, visible: :all)
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst live')
          expect(page).to have_css('#multiplex-status-button.multiplex-driving')
          expect(page).not_to have_css('#multiplex-toast.visible', text: 'Es geht gleich los!') # the host announces to the room, not to itself
          # Locked to the song: 📖 would otherwise jump straight back to the TOC
          expect(page).to have_css('#go-to-toc', visible: false)
        end

        # The client is snapped on, told which song is coming via a toast, then locked
        using_session(:client) do
          wait_for_js("Reveal.getIndices().h === 3")
          song = page.evaluate_script("document.querySelectorAll('.slides > section')[3].querySelector('h1').textContent.trim()")
          expect(page).to have_css('#multiplex-toast.visible', text: 'Es geht gleich los!')
          expect(page).to have_css('#multiplex-toast.visible', text: song)

          expect(page).to have_css('#multiplex-status', text: 'Folgt')
          expect(page).to have_css('#multiplex-status-button.multiplex-following')
          expect(page).to have_css('#go-to-toc', visible: false)
          before = slide_indices
          press(:right)
          press(:space)
          sleep 0.3
          expect(slide_indices).to eq(before)
          expect(page).to have_no_css('.reveal .controls') # no chevrons either
        end

        # The presenter scrolls down within the song; the client follows
        using_session(:presenter) do
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
        end
        using_session(:client) do
          wait_for_js("Reveal.getIndices().v === 1")
          expect(slide_indices).to eq([3, 1])
        end

        # The song is a wall — right does not leave it, even for the presenter
        using_session(:presenter) do
          find('body').send_keys(:right)
          sleep 0.3
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(3)

          # A horizontal swipe does nothing either — it used to navigate to the
          # neighbouring song and snap back to this one's title slide (v = 0).
          swipe(dx: -250, dy: 0)
          sleep 0.3
          expect(slide_indices).to eq([3, 1])

          # A vertical swipe still scrolls the song: the scroller needs it.
          swipe(dx: 0, dy: 250) # finger down → previous sub-slide
          wait_for_js("Reveal.getIndices().v === 0")
          expect(slide_indices).to eq([3, 0])

          # reveal.js binds Home to the first slide and End to the last one —
          # both used to reach the snap-back too, landing the presenter back on
          # v = 0 instead of leaving the scroll position alone (the snap-back
          # fired after the jump, not before it); they stay fully blocked, with
          # no vertical equivalent worth offering instead.
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
          find('body').send_keys(:home)
          sleep 0.3
          expect(slide_indices).to eq([3, 1])
          find('body').send_keys(:end)
          sleep 0.3
          expect(slide_indices).to eq([3, 1])

          # Space/Shift+Space default to reveal.js's own next()/prev(), the
          # same escape-prone bindings as above — remapped to step within the
          # song instead, exactly like the (already safe) arrow keys.
          press(:space)
          wait_for_js("Reveal.getIndices().v === 2")
          expect(slide_indices).to eq([3, 2])
          press([:shift, :space])
          wait_for_js("Reveal.getIndices().v === 1")
          expect(slide_indices).to eq([3, 1])
        end

        # The song book reopened mid-song restores the role on both sides,
        # from the device's storage (the address carries no session): no
        # password prompt again for the presenter, and no flash of free
        # navigation for the client while waiting for the next heartbeat to
        # re-establish it. The presenter comes back as a new tab would — the
        # home screen's app restarted, say: a plain address, and a new sender
        # id (sessionStorage is per tab), under which it names itself scroller
        # again. The song (h) is guaranteed by the restore itself; the exact
        # sub-slide (v) depends on reveal.js's own hash write, which is
        # debounced up to a second behind rapid moves — not asserted here.
        using_session(:presenter) do
          page.execute_script("sessionStorage.clear()")
          visit FixtureBuilder::URL_PATH
          wait_for_reveal
          expect(page).to have_css('#live-toggle.live-active', text: /🚀\s+Live-Scrollen beenden/, visible: :all)
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst live')
          wait_for_js("Reveal.getIndices().h === 3")
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(3)
          page.execute_script("window.MULTIPLEX.heartbeat = 200") # a new page: the spec's short heartbeat again
        end
        using_session(:client) do
          page.refresh
          wait_for_reveal
          expect(page).to have_css('#multiplex-status', text: 'Folgt')
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(3)
          before = slide_indices
          find('body').send_keys(:right) # still locked immediately, not just once the next heartbeat arrives
          sleep 0.3
          expect(slide_indices).to eq(before)
        end
        # And the room still follows the presenter under its new id
        using_session(:presenter) do
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
          expect(slide_indices).to eq([3, 1])
        end
        using_session(:client) do
          wait_for_js("Reveal.getIndices().v === 1")
          expect(slide_indices).to eq([3, 1])
        end

        # Ending drops everyone back on the TOC, frees them, and shows the notice
        using_session(:presenter) do
          press_live('Live-Scrollen beenden')
          expect(page).to have_no_css('#live-toggle.live-active', visible: :all)
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          wait_for_js("Reveal.getIndices().h === 1") # sent to the table of contents
          expect(slide_indices).to eq([1, 0])
          expect(page).to have_link('Table of contents') # free again: 📖 is back
          expect(page).to have_no_css('#multiplex-status-button.multiplex-driving')
          expect(page).to have_css('#multiplex-status', text: 'Du bist Gastgeber') # still, for the next song
        end
        using_session(:client) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          wait_for_js("Reveal.getIndices().h === 1") # every follower lands on the TOC too
          expect(slide_indices).to eq([1, 0])
          expect(page).to have_link('Table of contents')
          expect(page).to have_no_css('#multiplex-status-button.multiplex-following')
          expect(page).to have_css('.reveal .controls') # the chevrons are back
          # free to browse again. press, not send_keys on body: that clicks the
          # middle of the page first, which on the TOC can be a song's link
          press(:right)
          wait_for_js("Reveal.getIndices().h === 2")
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(2)
        end
      end

      it 'guest-scroll: the first volunteer leads the room, is walled into the song, and is thanked when it starts and when it ends' do
        secret = nil
        using_session(:presenter) do
          load_presentation
          log_in_as_host
          secret = session_secret
        end
        [:guest_a, :guest_b].each do |s|
          using_session(s) do
            join_session(secret)
            expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv') # connected
          end
        end

        using_session(:presenter) do
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          start_live(mode: :guest)
          expect(page).to have_css('#multiplex-status', text: 'Warte auf Gast …')
          expect(page).to have_css('#multiplex-status-button.multiplex-waiting')
        end

        [:guest_a, :guest_b].each do |s|
          using_session(s) { expect(page).to have_visible('#guest-invite-modal') }
        end

        using_session(:guest_a) do
          within('#guest-invite-modal') { click_button('Ja, ich scrolle') }
          wait_for_js("Reveal.getIndices().h === 4")
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst für alle')
          expect(page).to have_css('#multiplex-status-button.multiplex-driving')
          # Chosen as scroller: thanked for volunteering, not left to guess from the status line alone
          expect(page).to have_css('#multiplex-toast.visible', text: 'Danke für deine Bereitschaft! Lass uns gleich starten…')
        end

        using_session(:guest_b) do
          expect(page).not_to have_visible('#guest-invite-modal')
          wait_for_js("Reveal.getIndices().h === 4")
          expect(page).to have_css('#multiplex-status', text: 'Folgt')
          # Invited but never answered: told things are starting anyway, same as a decline would be
          expect(page).to have_css('#multiplex-toast.visible', text: 'Es geht gleich los!')
        end
        using_session(:presenter) do
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')
          # Handed to the guest: the presenter now follows too (ring, not dot)
          expect(page).to have_css('#multiplex-status-button.multiplex-following')
          # A quick heads-up that someone stepped up, instead of a silent status-line change
          expect(page).to have_css('#multiplex-toast.visible', text: 'Jemand hat sich bereit erklärt, es geht gleich los')
        end

        # The guest scrolls down; the whole room — the presenter included — follows
        using_session(:guest_a) do
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
        end
        using_session(:guest_b) { wait_for_js("Reveal.getIndices().v === 1"); expect(slide_indices).to eq([4, 1]) }
        using_session(:presenter) { wait_for_js("Reveal.getIndices().v === 1"); expect(slide_indices).to eq([4, 1]) }

        # The guest is walled into the song too
        using_session(:guest_a) do
          find('body').send_keys(:right)
          sleep 0.3
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(4)
        end

        # A reload keeps the guest recognised as the same scroller — senderId
        # is stable across a reload, so the host's broadcast (still naming
        # that id) locks this tab back in immediately, not just a stray follower.
        # Only h is asserted: v depends on reveal.js's own debounced hash write.
        using_session(:guest_a) do
          page.refresh
          wait_for_reveal
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst für alle')
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(4)
          find('body').send_keys(:right) # still walled in right away
          sleep 0.3
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(4)
        end

        # Ending thanks the guest, frees the room, and sends everyone to the TOC
        using_session(:presenter) do
          press_live('Live-Scrollen beenden')
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
        end
        using_session(:guest_a) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Vielen Dank fürs Scrollen!')
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
        end
        using_session(:guest_b) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          expect(page).to have_no_css('#multiplex-toast', text: 'Vielen Dank fürs Scrollen!')
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
        end
      end

      it 'another device takes the host role over: the old host steps down but keeps scrolling, and the new host ends the song' do
        secret = nil
        using_session(:josua) do
          load_presentation
          log_in_as_host
          secret = session_secret
        end
        using_session(:monika) do
          join_session(secret)
          expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv') # connected
        end
        using_session(:josua) do
          page.evaluate_script("Reveal.slide(3, 0)")
          wait_for_js("Reveal.getIndices().h === 3")
          start_live(mode: :self)
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst live')
        end

        using_session(:monika) do
          expect(page).to have_css('#multiplex-status', text: 'Folgt')
          # Her phone's clock runs an hour behind Josua's. The takeover wins
          # all the same: its claim is above every claim heard in the session.
          page.execute_script("var realNow = Date.now; Date.now = function() { return realNow() - 3600000; };")
          log_in_as_host(label: 'Gastgeber übernehmen')
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du bist jetzt Gastgeber')
          expect(session_secret).to eq(secret) # the same session, not a new one
          # The song carries on as it was: Josua still scrolls it
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')
          expect(page).to have_css('#live-toggle.live-active', text: /🚀\s+Live-Scrollen beenden/, visible: :all)
        end

        using_session(:josua) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Jemand anderes ist jetzt Gastgeber')
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst für alle')
          open_live_scroll_dialog
          within('#multiplex-info-modal') do
            expect(page).to have_no_button('🚀 Live-Scrollen beenden')
            expect(page).to have_no_button('🏁 Session beenden')
            expect(page).to have_button('🔗 QR-Code zeigen') # still in the session
            expect(page).to have_button('🔑 Gastgeber übernehmen') # and may take it back
          end
          press(:escape)
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
        end
        using_session(:monika) do
          wait_for_js("Reveal.getIndices().v === 1") # following Josua
          expect(slide_indices).to eq([3, 1])
          press_live('Live-Scrollen beenden')
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
        end
        using_session(:josua) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Vielen Dank fürs Scrollen!')
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
          expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv')
        end
      end

      it 'keeps two sessions apart and a plain visitor out of both; 🏁 sends a session home, 🚪 lets a guest out' do
        secret_a = secret_b = nil
        using_session(:host_a) do
          load_presentation
          log_in_as_host
          secret_a = session_secret
        end
        using_session(:host_b) do
          load_presentation
          log_in_as_host
          secret_b = session_secret
        end
        expect(secret_b).not_to eq(secret_a)
        using_session(:client_a) do
          join_session(secret_a)
          expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv') # connected
        end
        using_session(:client_b) do
          join_session(secret_b)
          expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv')
        end
        using_session(:visitor) do
          load_presentation
          expect(page).to have_css('#multiplex-status', text: 'Keine Session')
        end

        using_session(:host_b) do
          page.evaluate_script("Reveal.slide(4, 0)")
          wait_for_js("Reveal.getIndices().h === 4")
          start_live(mode: :self)
        end
        # The control: B's own client follows. By then A's would have too.
        using_session(:client_b) do
          wait_for_js("Reveal.getIndices().h === 4")
          expect(page).to have_css('#multiplex-status', text: 'Folgt')
        end
        using_session(:client_a) do
          expect(slide_indices).to eq([0, 0])
          expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv')
        end
        using_session(:visitor) { expect(slide_indices).to eq([0, 0]) }
        using_session(:host_a) do
          # Not stepped down by a host of another session
          expect(page).to have_css('#multiplex-status', text: 'Du bist Gastgeber')
          page.evaluate_script("Reveal.slide(3, 0)")
          wait_for_js("Reveal.getIndices().h === 3")
          start_live(mode: :self)
          open_live_scroll_dialog
          within('#multiplex-info-modal') { click_button('🏁 Session beenden') }
          expect(page).to have_css('#multiplex-status', text: 'Keine Session')
        end
        # Ending a session mid-song frees its devices, takes them to the TOC
        # and out of the session: the address loses ?live=
        using_session(:client_a) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Die Session ist beendet')
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          expect(page).to have_css('#multiplex-status', text: 'Keine Session')
          expect(session_secret).to be_nil
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
        end
        using_session(:client_b) do
          expect(page).to have_css('#multiplex-status', text: 'Folgt') # the other session runs on
          expect(session_secret).to eq(secret_b)

          # A guest may leave of its own accord, even mid-song: free where it stands
          open_live_scroll_dialog
          within('#multiplex-info-modal') do
            expect(page).to have_no_button('🏁 Session beenden') # the host's
            click_button('🚪 Session verlassen')
          end
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du hast die Session verlassen')
          expect(page).to have_css('#multiplex-status', text: 'Keine Session')
          expect(session_secret).to be_nil
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(4)
          press(:right)
          wait_for_js("Reveal.getIndices().h === 5")
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(5)
          # And stays out, across a reload too
          page.refresh
          wait_for_reveal
          expect(page).to have_css('#multiplex-status', text: 'Keine Session')
        end
        using_session(:host_b) do
          open_live_scroll_dialog
          within('#multiplex-info-modal') { expect(page).to have_no_button('🚪 Session verlassen') } # the host ends it instead
        end
      end

      it 'a guest who volunteers but loses the race is told someone else is already scrolling' do
        using_session(:guest) do
          join_session('spec-race')
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          install_spy
          spy_send_host({ id: 'spy-1', song: 4, songTitle: 'Across the universe', mode: 'guest', scrollerId: nil }, fresh: true)
          expect(page).to have_visible('#guest-invite-modal')

          within('#guest-invite-modal') { click_button('Ja, ich scrolle') }
          expect(page).not_to have_visible('#guest-invite-modal')

          spy_send_host({ id: 'spy-1', song: 4, songTitle: 'Across the universe', mode: 'guest', scrollerId: 'someone-else' })
          expect(page).to have_css('#multiplex-toast.visible', text: 'Oh, das wäre nett gewesen – aber jemand anderes scrollt bereits!')
          expect(page).to have_css('#multiplex-status', text: 'Folgt') # the room still runs; this guest just isn't the one scrolling
        end
      end

      it 'the host stays in the live scroll after handing off, before the guest has sent any state' do
        using_session(:presenter) do
          load_presentation
          log_in_as_host(heartbeat: 3000)
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          install_phantom_guest
          wait_for_js("window._phantom && window._phantom.connected")

          start_live(mode: :guest)
          expect(page).to have_css('#multiplex-status', text: 'Warte auf Gast …')

          # The guest takes over but sends no state yet. The host becomes a
          # follower and must stay in the live scroll — it used to free itself
          # at the next release tick, because at hand-off its own lastSessionAt
          # was still 0.
          wait_for_js("window._phantom.liveId !== null")
          page.execute_script("window._phantomVolunteer()")
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')
          sleep 0.8 # well past the 500ms release-checker tick
          expect(page).to have_css('#live-toggle.live-active', visible: :all)
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')
        end
      end

      it 'the host keeps the ability to end the live scroll even if the guest it handed off to goes silent for a while' do
        using_session(:presenter) do
          load_presentation
          # heartbeat: 300, not the usual fast 100/200ms other specs use: the
          # release-checker ticks on a fixed 500ms, independent of cfg.heartbeat
          # (see body-controls.html) — a staleness threshold shorter than that
          # tick (3 * 100 = 300ms < 500ms) can never be observed as "fresh"
          # again, since by the time the next tick runs more than 300ms has
          # always already passed. 3 * 300 = 900ms comfortably clears it.
          log_in_as_host(heartbeat: 300)
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          install_phantom_guest
          wait_for_js("window._phantom && window._phantom.connected")

          start_live(mode: :guest)
          wait_for_js("window._phantom.liveId !== null")
          page.execute_script("window._phantomVolunteer()")
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')

          # The phantom guest never sends any state at all. Past three missed
          # heartbeats (900ms here) an ordinary follower frees itself — and
          # before the host was exempted from that, so did the host: the ❌
          # vanished and 🚀 reverted to "Live-Scrollen starten", even though
          # the guest — and everyone else still locked to it — carried on
          # regardless. A flaky connection to the guest must not cost the
          # host its own ability to end the live scroll.
          sleep 1.1
          expect(page).to have_css('#live-toggle.live-active', text: /🚀\s+Live-Scrollen beenden/, visible: :all)
          # Told why the view has stopped moving, instead of silently wondering
          expect(page).to have_css('#multiplex-toast.visible',
            text: 'Keine Rückmeldung mehr vom scrollenden Gerät – du kannst das Live-Scrollen bei Bedarf beenden')

          # The guest comes back: told so, once
          page.execute_script("window._phantomState()")
          expect(page).to have_css('#multiplex-toast.visible', text: 'Das scrollende Gerät ist wieder verbunden')

          press_live('Live-Scrollen beenden')
          expect(page).to have_no_css('#live-toggle.live-active', visible: :all)
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
        end
      end

      it 'shows a toast when the connection drops and when it comes back, on top of the persistent status line' do
        using_session(:presenter) do
          load_presentation
          log_in_as_host
          page.evaluate_script("Reveal.slide(3, 0)")
          wait_for_js("Reveal.getIndices().h === 3")
          start_live(mode: :self)
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst live')

          # window.MULTIPLEX.socket is a seam for exactly this: Chrome's CDP
          # offline emulation does not reliably sever an already-open
          # WebSocket, so the only way to simulate a real drop here is to
          # disconnect the actual socket the page is using.
          page.execute_script("window.MULTIPLEX.socket.disconnect()")
          expect(page).to have_css('#multiplex-status', text: 'Keine Verbindung')
          expect(page).to have_css('#multiplex-status-button.multiplex-disconnected')
          expect(page).to have_css('#multiplex-toast.visible', text: 'Verbindung verloren')

          page.execute_script("window.MULTIPLEX.socket.connect()")
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst live')
          expect(page).to have_no_css('#multiplex-status-button.multiplex-disconnected')
          expect(page).to have_css('#multiplex-toast.visible', text: 'Wieder verbunden')
        end
      end

      it 'repeats the end of a live scroll on every heartbeat, and the end of the session twice more, so one dropped packet strands nobody' do
        using_session(:presenter) do
          load_presentation
          log_in_as_host
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          start_live(mode: :self)
          install_spy
          page.execute_script(<<~JS)
            window._liveEnded = 0;
            window._sessionEnded = 0;
            window._spy.on(window.MULTIPLEX.socketId, function(data) {
              if (data && data.type === 'host' && data.live === null) window._liveEnded++;
              if (data && data.type === 'end') window._sessionEnded++;
            });
          JS

          press_live('Live-Scrollen beenden')
          wait_for_js("window._liveEnded >= 3") # the heartbeat is 200ms here
          expect(page.evaluate_script('window._liveEnded')).to be >= 3

          open_live_scroll_dialog
          within('#multiplex-info-modal') { click_button('🏁 Session beenden') }
          wait_for_js("window._sessionEnded >= 3") # now, and again over the next second
          expect(page.evaluate_script('window._sessionEnded')).to be >= 3
        end
      end

      it 'a device that joins mid-song follows straight away, without an invite' do
        secret = nil
        using_session(:presenter) do
          load_presentation
          log_in_as_host
          secret = session_secret
          page.evaluate_script("Reveal.slide(5, 0)") # I Have a Dream
          wait_for_js("Reveal.getIndices().h === 5")
          start_live(mode: :self)
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
        end

        using_session(:latecomer) do
          join_session(secret)
          wait_for_js("Reveal.getIndices().h === 5 && Reveal.getIndices().v === 1", timeout: 5)
          expect(slide_indices).to eq([5, 1])
          expect(page).not_to have_visible('#guest-invite-modal')
          expect(page).not_to have_css('#multiplex-toast.visible', text: 'Es geht gleich los!') # joined mid-song: no announcement
          expect(page).to have_css('#multiplex-status', text: 'Folgt')
        end
      end
    end

    describe 'multiplex status dialog' do
      before { load_presentation }

      it 'opens with the current status, and closes on Esc, close button and outside click' do
        expect(page).not_to have_visible('#multiplex-info-modal')
        expect(page).to have_css('#multiplex-status-button[aria-haspopup="dialog"]')

        find('#multiplex-status-button').click
        expect(page).to have_visible('#multiplex-info-modal')
        expect(active_element_id).to eq('multiplex-info-title')
        expect(page).to have_css('#multiplex-info-status', text: 'Keine Session')
        within('#multiplex-info-modal') do # outside a session, only the way in
          expect(page).to have_button('🔑 Als Gastgeber anmelden')
          expect(page).to have_no_button('🔗 QR-Code zeigen')
        end

        # Reveal listens on the document: nothing pressed inside the dialog reaches it
        before = slide_indices
        press(:right)
        expect(slide_indices).to eq(before)
        press(:escape)
        expect(page).not_to have_visible('#multiplex-info-modal')
        expect(page.evaluate_script("Reveal.isOverview()")).to be false
        expect(active_element_id).to eq('multiplex-status-button')

        find('#multiplex-status-button').click
        click_button('Schliessen')
        expect(page).not_to have_visible('#multiplex-info-modal')

        find('#multiplex-status-button').click
        expect(page).to have_visible('#multiplex-info-modal')
        backdrop_click('multiplex-info-modal')
        expect(page).not_to have_visible('#multiplex-info-modal')
      end
    end

    describe 'QR modal' do
      # The control tooltips only show on a hover-capable pointer:
      # body-controls.html gates them on matchMedia('(hover: hover)'). Headless
      # Chrome on the Linux runner reports that false (and CDP cannot emulate the
      # hover media feature), so simulate a mouse by making matchMedia report it,
      # injected before the page's own scripts capture the query.
      before do
        page.driver.browser.page.command(
          'Page.addScriptToEvaluateOnNewDocument',
          source: <<~JS
            (function () {
              var orig = window.matchMedia.bind(window);
              window.matchMedia = function (q) {
                var mql = orig(q);
                if (q.indexOf('hover: hover') !== -1) {
                  Object.defineProperty(mql, 'matches', { configurable: true, get: function () { return true; } });
                }
                return mql;
              };
            })();
          JS
        )
      end
      before { join_session('spec-qr') } # anyone in a session may show its code, not only the host

      # 🔗 sits in the 📡 dialog, which closes as the QR opens
      def open_qr
        open_live_scroll_dialog
        within('#multiplex-info-modal') { click_button('🔗 QR-Code zeigen') }
        expect(page).not_to have_visible('#multiplex-info-modal')
      end

      it 'carries the session, keeps the keys to itself, and closes on Esc, close button and outside click' do
        expect(page).not_to have_visible('#qr-modal')
        expect(page).to have_css('#show-qr[aria-haspopup="dialog"]', visible: :all)
        # A corner button's label is its tooltip, on hover
        expect(tooltip_shown?('multiplex-status-button')).to be false
        find('#multiplex-status-button').hover
        expect(tooltip_shown?('multiplex-status-button')).to be true

        open_qr
        expect(page).to have_visible('#qr-modal')
        expect(active_element_id).to eq('qr-title')
        # Whoever scans it is in the session, and shows their own code right away
        expect(page).to have_css('#qr-canvas img[alt^="QR-Code für http"][alt$="?live=spec-qr&qr=1"]', visible: :all)

        # Wide viewports (this spec's default window is 1280x800, past the
        # 769px breakpoint night.css switches on): the QR sits beside the text
        # and the close button, not stacked below them where a tall dialog
        # could clip against a short viewport.
        wide = page.evaluate_script(<<~JS)
          (function() {
            function r(sel) { return document.querySelector(sel).getBoundingClientRect(); }
            var box = r('.modal-box-qr'), text = r('.qr-text'), canvas = r('#qr-canvas'), close = r('#qr-close');
            return [box.right, text.right, canvas.left, close.right, window.innerWidth];
          })();
        JS
        box_right, text_right, canvas_left, close_right, viewport_width = wide
        expect(canvas_left).to be >= text_right
        expect(canvas_left).to be >= close_right
        expect(box_right).to be <= viewport_width

        # Narrower than that breakpoint: back to the original stacked order —
        # text, then the QR, then the close button — instead of side by side.
        begin
          page.driver.browser.resize(width: 375, height: 812)
          wait_for_js("getComputedStyle(document.querySelector('.modal-box-qr')).display !== 'grid'")
          narrow = page.evaluate_script(<<~JS)
            (function() {
              function r(sel) { return document.querySelector(sel).getBoundingClientRect(); }
              var text = r('.qr-text'), canvas = r('#qr-canvas'), close = r('#qr-close');
              return [text.bottom, canvas.top, canvas.bottom, close.top];
            })();
          JS
          text_bottom, canvas_top, canvas_bottom, close_top = narrow
          expect(canvas_top).to be >= text_bottom
          expect(close_top).to be >= canvas_bottom
        ensure
          page.driver.browser.resize(width: 1280, height: 800)
        end

        # Reveal listens on the document: nothing pressed inside the dialog reaches it
        before = slide_indices
        press(:right)
        expect(slide_indices).to eq(before)
        press(:escape)
        expect(page).not_to have_visible('#qr-modal')
        expect(page.evaluate_script("Reveal.isOverview()")).to be false
        expect(active_element_id).to eq('multiplex-status-button') # back where the way in began

        open_qr
        within(find('#qr-modal', visible: :all)) { click_button('Schliessen') }
        expect(page).not_to have_visible('#qr-modal')

        open_qr
        expect(page).to have_visible('#qr-modal')
        backdrop_click('qr-modal')
        expect(page).not_to have_visible('#qr-modal')
      end
    end

    describe 'QR modal, joined via a scanned code' do
      it 'shows its own QR right away, keeps the session on the device instead of the address, and forgets it after twelve silent hours' do
        # Every address written, from the very start of the page
        page.driver.browser.page.command('Page.addScriptToEvaluateOnNewDocument', source: <<~'JS')
          window._addresses = [];
          var replaceState = history.replaceState.bind(history);
          history.replaceState = function(state, title, url) {
            window._addresses.push(String(url));
            return replaceState(state, title, url);
          };
        JS
        visit FixtureBuilder::URL_PATH + '?live=spec-qr&qr=1'
        wait_for_reveal
        # Reveal writes the address itself, at most once a second, and a write
        # it deferred carries the query string of the moment it was asked
        # for: had it ever seen ?live=, it could put it back a second after it
        # was dropped — and after „Session verlassen", a reload joined again.
        # So ?live= is gone before Reveal starts, and no write carries it.
        expect(page.evaluate_script("window._addresses.length")).to be > 0 # Reveal's own, at least
        expect(page.evaluate_script("window._addresses.filter(function(a) { return /[?&]live=/.test(a); })")).to eq([])
        expect(page).to have_visible('#qr-modal')
        expect(active_element_id).to eq('qr-title')
        # The session and the marker are put into the freshly generated code
        # (so the chain of scans keeps going), but removed from the address
        # bar itself: the session is in the device's storage now.
        expect(page).to have_css('#qr-canvas img[alt^="QR-Code für http"][alt$="?live=spec-qr&qr=1"]', visible: :all)
        expect(page.evaluate_script('window.location.search')).to eq('')
        expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv') # in the session
        expect(session_secret).to eq('spec-qr')

        # Nobody hosts this one, so nothing keeps it alive: eleven hours since
        # it was last heard of, it is still this evening's…
        age = ->(hours) { page.execute_script(<<~JS) }
          var s = JSON.parse(localStorage.getItem('multiplex-session'));
          s.seenAt = Date.now() - #{hours} * 3600 * 1000;
          localStorage.setItem('multiplex-session', JSON.stringify(s));
        JS
        age.call(11)
        page.refresh
        wait_for_reveal
        expect(page).to have_css('#multiplex-status', text: 'Kein Live-Scrollen aktiv')
        # …thirteen hours, and it is a past evening, forgotten
        age.call(13)
        page.refresh
        wait_for_reveal
        expect(page).to have_css('#multiplex-status', text: 'Keine Session')
        expect(session_secret).to be_nil
      end
    end

  end
end
