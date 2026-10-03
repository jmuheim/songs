require 'capybara/rspec'

RSpec.describe 'index.html', :js, type: :feature do
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
    # v=0 is the song's title slide, v=1 its About (tags) slide; the first slide
    # that carries chords is v=2.
    page.evaluate_script("Reveal.slide(3, 2)")
    wait_for_js("Reveal.getIndices().h === 3 && Reveal.getIndices().v === 2")
  end

  def backdrop_click(id)
    page.execute_script("document.getElementById('#{id}').click()") # e.target must be the overlay, not a child
  end

  # Enter the password, then pick who scrolls. The heartbeat is shortened so
  # late joiners and the end-of-session notice arrive quickly. Presenter tabs.
  def start_scroll_session(mode:, heartbeat: 200)
    page.execute_script("window.MULTIPLEX.heartbeat = #{heartbeat}")
    click_button('🚀 Live-Scrollen starten')
    within('#master-modal') do
      find('#master-pw').set(page.evaluate_script("window.MULTIPLEX.password"))
      click_button('Weiter')
    end
    within('#scroll-choice-modal') do
      click_button(mode == :self ? 'Ich selber möchte scrollen' : 'Ein Gast soll scrollen')
    end
  end

  # A second socket (forceNew, so the relay sees it as another client) that learns
  # the live session id from the presenter's own heartbeat and then, on demand,
  # volunteers under an id no real tab owns. The named scroller therefore never
  # sends any state — exactly the live moment just after a guest takes over, its
  # first state still crossing the network. Real localhost tabs can't reproduce
  # it: their state arrives in milliseconds, before the release checker's next tick.
  def install_phantom_guest
    page.execute_script(<<~JS)
      window._phantom = { connected: false, sessionId: null };
      var cfg = window.MULTIPLEX;
      var spy = io(cfg.url, { forceNew: true });
      spy.on('connect', function() { window._phantom.connected = true; });
      spy.on(cfg.socketId, function(data) {
        if (data && data.type === 'session' && data.session && data.session.active &&
            data.session.mode === 'guest' && !data.session.scrollerId) {
          window._phantom.sessionId = data.session.id;
        }
      });
      window._phantomVolunteer = function() {
        spy.emit('multiplex-statechanged', {
          type: 'volunteer', sessionId: window._phantom.sessionId, from: 'phantom-guest',
          secret: cfg.secret, socketId: cfg.socketId
        });
      };
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
      expect(page).to have_css('#title-slide.present')
      expect(page.evaluate_script("document.documentElement.lang")).to eq('de-CH')
      within('#top-left-controls') do
        expect(page).to have_link('📖 Table of contents')
        expect(page).to have_button('🎹 Hide chords')
      end
      within('#top-right-controls') do
        expect(page).to have_button('🔗 Show QR code')
        expect(page).to have_button('🚀 Live-Scrollen starten', disabled: true) # off a song on the title slide
        expect(page).to have_button('🌞 Switch to bright mode')
      end

      socket_id = page.evaluate_script("window.MULTIPLEX && window.MULTIPLEX.socketId")
      expect(socket_id).not_to be_nil
      expect(socket_id).not_to be_empty

      # title-slide + TOC + Introduction + fixture songs
      expect(all('.slides > section', visible: :all).size).to eq(3 + song_count)
    end

    it 'centers the title slide content vertically' do
      # #title-slide has no sub-slides, so it never gets wrapped in a .stack —
      # the flex rule that centers every other top-level section vertically
      # among its children does not apply to it, so it needs its own.
      rects = page.evaluate_script(<<~JS)
        (function() {
          var section = document.getElementById('title-slide').getBoundingClientRect();
          var content = document.querySelector('#title-slide .slide-content').getBoundingClientRect();
          return [section.top, section.height, content.top, content.height];
        })();
      JS
      section_top, section_height, content_top, content_height = rects
      expect(content_top).to be_within(1).of(section_top + (section_height - content_height) / 2)
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

    it 'has built-in controls disabled' do
      expect(page.evaluate_script("Reveal.getConfig().controls")).to be false
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

    it 'sets zoom on slide change and recalculates on window resize' do
      # The verse and clamp values are exact on every platform (both are pure
      # text — the fonts are bundled, so they render identically). The title
      # slide carries emoji, which Chrome lays out differently across its own
      # builds (see decisions/2026-09-30-emoji-zoom-is-not-reproducible-across-
      # chrome-builds.md); its exact zoom therefore only holds locally, so on the
      # CI runner we assert only that the title is zoomed up to fill.
      if ENV['CI']
        wait_for_js("document.querySelector('#title-slide .slide-content').style.zoom !== ''")
        title_zoom = page.evaluate_script("parseFloat(document.querySelector('#title-slide .slide-content').style.zoom)")
        expect(title_zoom).to be_between(1.3, 1.7)
      else
        expect(page).to have_css('#title-slide .slide-content[style="zoom: 1.41436;"]', visible: :all)
      end

      page.evaluate_script("Reveal.slide(2, 1)")
      expect(page).to have_css('section.present.level2 .slide-content[style="zoom: 0.763268;"]', visible: :all)

      page.evaluate_script("Reveal.slide(0, 0)")
      page.driver.browser.resize(width: 480, height: 600)
      page.evaluate_script("window.dispatchEvent(new Event('resize'))") # Cuprite's resize doesn't fire the browser event
      expect(page).to have_css('#title-slide .slide-content[style="zoom: 1;"]', visible: :all)
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end
  end

  # -----------------------------------------------------------------------
  # TOC navigation
  # -----------------------------------------------------------------------
  describe 'TOC navigation' do
    before { load_presentation }

    it 'has correct structure and navigates on click' do
      expect(page).to have_css('#go-to-toc[href="#/1"]')
      expect(all('#TOC a', visible: :all).size).to eq(song_count + 1) # +1 for Introduction

      click_link('Table of contents')
      expect(page).to have_css('#TOC.present')

      click_link 'Introduction'
      expect(page).to have_css('#introduction.present')
    end
  end

  # -----------------------------------------------------------------------
  # Chord visibility toggle
  # -----------------------------------------------------------------------
  describe 'chord visibility toggle' do
    before do
      load_presentation
      go_to_first_song
    end

    it 'toggles chord visibility' do
      expect(page).to have_no_css('body.chords-hidden')
      within 'section.slide.present' do
        expect(page).to have_css('code')
        expect(page).to have_no_css('code', visible: :hidden)
      end
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="false"]')

      click_button('🎹 Hide chords')
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="true"]', text: /🎹\s+Hide chords/)
      expect(page).to have_css('body.chords-hidden')
      within 'section.slide.present' do
        expect(page).to have_css('code', visible: :hidden)
        expect(page).to have_no_css('code')
      end

      click_button('🎹 Hide chords')
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="false"]', text: /🎹\s+Hide chords/)
      expect(page).to have_no_css('body.chords-hidden')
      within 'section.slide.present' do
        expect(page).to have_css('code')
        expect(page).to have_no_css('code', visible: :hidden)
      end

      # Clicked with the mouse, 🎹 keeps a focus nobody sees: Space turns the page instead
      click_button('🎹 Hide chords')
      before = slide_indices
      press(:space)
      wait_for_js("Reveal.getIndices().v !== #{before[1]}")
      expect(slide_indices).not_to eq(before)
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="true"]')

      # Reached with the keyboard, its focus shows: Space presses it, and the slide stays.
      # The mouse leaves first: keys pressed while it rested on 🎹 dismissed its tooltip.
      page.driver.browser.mouse.move(x: 640, y: 500)
      20.times { break if active_element_id == 'toggle-chords-visibility'; press(:tab) }
      expect(active_element_id).to eq('toggle-chords-visibility')

      # The keyboard focus shows the label as a tooltip; Esc hides it without opening the overview
      expect(tooltip_shown?('toggle-chords-visibility')).to be true
      press(:escape)
      expect(tooltip_shown?('toggle-chords-visibility')).to be false
      expect(page.evaluate_script("Reveal.isOverview()")).to be false

      before = slide_indices
      press(:space)
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="false"]')
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

    it 'toggles theme, persists preference, and restores on reload' do
      expect(page).to have_no_css('body.theme-bright')
      expect(body_background_color).to eq('#111')
      expect(page).to have_css('#toggle-theme[aria-pressed="false"]', text: /🌞\s+Switch to bright mode/)

      click_button('🌞 Switch to bright mode')
      expect(page).to have_css('body.theme-bright')
      expect(body_background_color).to eq('#fffad5')
      expect(page.evaluate_script("localStorage.getItem('theme')")).to eq('bright')
      expect(page).to have_css('#toggle-theme[aria-pressed="true"]', text: /🌛\s+Switch to dark mode/)

      load_presentation
      expect(page).to have_css('body.theme-bright')

      click_button('🌛 Switch to dark mode')
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
        click_button('🌞 Switch to bright mode')
        expect(page).to have_css('body.theme-bright')
      end
    end
  end

  # -----------------------------------------------------------------------
  # Multiplex
  # -----------------------------------------------------------------------
  describe 'multiplex' do
    describe 'start dialog' do
      before { load_presentation }

      it 'the password gates the choice dialog, which opens no session by itself' do
        page.evaluate_script("Reveal.slide(3, 0)") # 🚀 only starts a session from a song
        wait_for_js("Reveal.getIndices().h === 3")
        expect(page).not_to have_visible('#master-modal')
        expect(page).to have_css('#master-mode[aria-pressed="false"]', text: /🚀\s+Live-Scrollen starten/)

        click_button('🚀 Live-Scrollen starten')
        expect(page).to have_visible('#master-modal')
        expect(active_element_id).to eq('master-pw')
        backdrop_click('master-modal')
        expect(page).not_to have_visible('#master-modal')

        click_button('🚀 Live-Scrollen starten')
        within('#master-modal') do
          find('#master-pw').set('something')
          click_button('Abbrechen')
        end
        expect(page).not_to have_visible('#master-modal')
        expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty

        click_button('🚀 Live-Scrollen starten')
        within('#master-modal') do
          find('#master-pw').set('wrongpassword')
          click_button('Weiter')
          expect(page).to have_css('#master-pw.shake')
          expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
        end
        expect(page).to have_visible('#master-modal')

        within('#master-modal') do
          find('#master-pw').set(page.evaluate_script("window.MULTIPLEX.password"))
          click_button('Weiter')
        end
        expect(page).not_to have_visible('#master-modal')
        # The choice dialog opens; no session is live yet.
        expect(page).to have_visible('#scroll-choice-modal')
        expect(page).to have_no_css('#master-mode.session-active')

        within('#scroll-choice-modal') { click_button('Abbrechen') }
        expect(page).not_to have_visible('#scroll-choice-modal')
        expect(page).to have_no_css('#master-mode.session-active')

        # Already authenticated: 🚀 goes straight to the choice, no password.
        click_button('🚀 Live-Scrollen starten')
        expect(page).to have_visible('#scroll-choice-modal')
        expect(page).not_to have_visible('#master-modal')
        within('#scroll-choice-modal') { click_button('Abbrechen') }
      end
    end

    describe '🚀 availability' do
      before { load_presentation }

      it 'enables 🚀 only on a song — disabled on the title, the TOC and the introduction' do
        master_disabled_at = lambda do |h|
          page.evaluate_script("Reveal.slide(#{h}, 0)")
          wait_for_js("Reveal.getIndices().h === #{h}")
          page.evaluate_script("document.getElementById('master-mode').disabled")
        end

        wait_for_js("document.getElementById('master-mode').disabled === true") # title slide on load
        expect(master_disabled_at.call(1)).to be true  # TOC
        expect(master_disabled_at.call(2)).to be true  # Introduction (a stack; its slug sits on the first sub-slide)
        expect(master_disabled_at.call(3)).to be false # the first song
        expect(master_disabled_at.call(1)).to be true  # back off a song
      end
    end

    describe 'live sync' do
      after { Capybara.reset_sessions! }

      it 'self-scroll: the room is snapped and locked, vertical moves propagate, the song is a wall, ending frees everyone' do
        using_session(:client) do
          load_presentation
          expect(page).to have_css('#title-slide.present')
        end

        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(3, 0)") # the first song
          wait_for_js("Reveal.getIndices().h === 3")
          start_scroll_session(mode: :self)
          expect(page).to have_css('#master-mode.session-active', text: /🚀\s+Live-Scrollen beenden/)
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst live')
          expect(page).not_to have_visible('#self-announce-modal') # the presenter announces to the room, not to itself
        end

        # The client is snapped on, told which song is coming, then locked
        using_session(:client) do
          wait_for_js("Reveal.getIndices().h === 3")
          expect(page).to have_visible('#self-announce-modal')
          expect(page).to have_css('#self-announce-modal', text: 'Es geht gleich los!')
          song = page.evaluate_script("document.querySelectorAll('.slides > section')[3].querySelector('h1').textContent.trim()")
          expect(page).to have_css('#self-announce-song', text: song)
          within('#self-announce-modal') { click_button('OK') } # dismiss, so the lock below is really the lock, not the modal
          expect(page).not_to have_visible('#self-announce-modal')

          expect(page).to have_css('#multiplex-status', text: 'Folgt')
          before = slide_indices
          press(:right)
          press(:space)
          sleep 0.3
          expect(slide_indices).to eq(before)
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

          # reveal.js binds Space to "next", Home to the first slide and End to
          # the last one — all of them used to reach the snap-back too, landing
          # the presenter back on v = 0 instead of leaving the scroll position
          # alone (the snap-back fired after the jump, not before it).
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
          find('body').send_keys(:space)
          sleep 0.3
          expect(slide_indices).to eq([3, 1])
          find('body').send_keys(:home)
          sleep 0.3
          expect(slide_indices).to eq([3, 1])
          find('body').send_keys(:end)
          sleep 0.3
          expect(slide_indices).to eq([3, 1])
        end

        # Ending drops everyone back on the TOC, frees them, and shows the notice
        using_session(:presenter) do
          click_button('🚀 Live-Scrollen beenden')
          expect(page).to have_no_css('#master-mode.session-active')
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          wait_for_js("Reveal.getIndices().h === 1") # sent to the table of contents
          expect(slide_indices).to eq([1, 0])
        end
        using_session(:client) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          wait_for_js("Reveal.getIndices().h === 1") # every follower lands on the TOC too
          expect(slide_indices).to eq([1, 0])
          find('body').send_keys(:right) # free to browse again
          wait_for_js("Reveal.getIndices().h === 2")
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(2)
        end
      end

      it 'guest-scroll: the first volunteer leads the room, is walled into the song, and is thanked when it ends' do
        [:guest_a, :guest_b].each do |s|
          using_session(s) { load_presentation; expect(page).to have_css('#title-slide.present') }
        end

        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          start_scroll_session(mode: :guest)
          expect(page).to have_css('#multiplex-status', text: 'Warte auf Gast …')
        end

        [:guest_a, :guest_b].each do |s|
          using_session(s) do
            expect(page).to have_visible('#guest-invite-modal')
            expect(page).not_to have_visible('#self-announce-modal') # that dialog is for self-scroll only
          end
        end

        using_session(:guest_a) do
          within('#guest-invite-modal') { click_button('Ja, ich scrolle') }
          wait_for_js("Reveal.getIndices().h === 4")
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst für alle')
        end

        using_session(:guest_b) do
          expect(page).not_to have_visible('#guest-invite-modal')
          wait_for_js("Reveal.getIndices().h === 4")
          expect(page).to have_css('#multiplex-status', text: 'Folgt')
        end
        using_session(:presenter) { expect(page).to have_css('#multiplex-status', text: 'Gast scrollt') }

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

        # Ending thanks the guest, frees the room, and sends everyone to the TOC
        using_session(:presenter) do
          click_button('🚀 Live-Scrollen beenden')
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

      it 'the presenter stays in the session after handing off, before the guest has sent any state' do
        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          install_phantom_guest
          wait_for_js("window._phantom && window._phantom.connected")

          start_scroll_session(mode: :guest, heartbeat: 3000)
          expect(page).to have_css('#multiplex-status', text: 'Warte auf Gast …')

          # The guest takes over but sends no state yet. The presenter becomes a
          # follower and must stay in the session — it used to free itself at the
          # next release tick, because at hand-off its own lastSessionAt was still 0.
          wait_for_js("window._phantom.sessionId !== null")
          page.execute_script("window._phantomVolunteer()")
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')
          sleep 0.8 # well past the 500ms release-checker tick
          expect(page).to have_css('#master-mode.session-active')
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')
        end
      end

      it 'a device that joins mid-session follows straight away, without an invite' do
        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(5, 0)") # I Have a Dream
          wait_for_js("Reveal.getIndices().h === 5")
          start_scroll_session(mode: :self)
          find('body').send_keys(:down)
          wait_for_js("Reveal.getIndices().v === 1")
        end

        using_session(:latecomer) do
          load_presentation
          wait_for_js("Reveal.getIndices().h === 5 && Reveal.getIndices().v === 1", timeout: 5)
          expect(slide_indices).to eq([5, 1])
          expect(page).not_to have_visible('#guest-invite-modal')
          expect(page).not_to have_visible('#self-announce-modal') # joined mid-session: no „Es geht gleich los!"
          expect(page).to have_css('#multiplex-status', text: 'Folgt')
        end
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
      before { load_presentation }

      it 'keeps the keys to itself, and closes on Esc, close button and outside click' do
        expect(page).not_to have_visible('#qr-modal')
        expect(page).to have_css('#show-qr[aria-haspopup="dialog"]')
        expect(tooltip_shown?('show-qr')).to be false
        find('#show-qr').hover
        expect(tooltip_shown?('show-qr')).to be true

        click_button('Show QR code')
        expect(page).to have_visible('#qr-modal')
        expect(active_element_id).to eq('qr-title')
        expect(page).to have_css('#qr-canvas img[alt^="QR-Code für http"]', visible: :all)

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
        expect(active_element_id).to eq('show-qr')

        click_button('Show QR code')
        within(find('#qr-modal', visible: :all)) { click_button('Schliessen') }
        expect(page).not_to have_visible('#qr-modal')

        click_button('Show QR code')
        expect(page).to have_visible('#qr-modal')
        backdrop_click('qr-modal')
        expect(page).not_to have_visible('#qr-modal')
      end
    end

    describe 'QR modal, joined via a scanned code' do
      it 'shows its own QR right away, with the join marker stripped from the address bar' do
        visit FixtureBuilder::URL_PATH + '?qr=1'
        wait_for_reveal
        expect(page).to have_visible('#qr-modal')
        expect(active_element_id).to eq('qr-title')
        # The marker is re-added to the freshly generated code (so the chain of
        # scans keeps going), but removed from the address bar itself.
        expect(page).to have_css('#qr-canvas img[alt^="QR-Code für http"][alt$="?qr=1"]', visible: :all)
        expect(page.evaluate_script('window.location.search')).to eq('')
      end
    end

  end
end
