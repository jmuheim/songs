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
    # v=0 is the song's title slide, v=1 its "Infos über das Lied" (tags) slide;
    # the first slide that carries chords is v=2.
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
      // Simulates the phantom guest resuming after a silence — a state
      // message is all it takes to refresh lastSessionAt on the receiving end.
      window._phantomState = function() {
        spy.emit('multiplex-statechanged', {
          type: 'state', sessionId: window._phantom.sessionId, state: { indexh: 4, indexv: 0 },
          from: 'phantom-guest', secret: cfg.secret, socketId: cfg.socketId
        });
      };
    JS
  end

  # A second socket (forceNew) that feeds a lone tab fabricated `session`
  # broadcasts, standing in for a presenter. Driving a real two-guest race to
  # test the *losing* side's feedback doesn't work: the relay resolves it in
  # milliseconds, well before a second real tab could still have its invite
  # open to lose from (see install_phantom_guest above for the same problem
  # from the presenter's side).
  def install_spy
    page.execute_script("window._spy = io(window.MULTIPLEX.url, { forceNew: true });")
    wait_for_js("window._spy.connected")
  end

  def spy_send_session(session, claim: 1, fresh: false)
    page.execute_script(<<~JS)
      window._spy.emit('multiplex-statechanged', Object.assign({
        type: 'session', claim: #{claim}, fresh: #{fresh}, session: #{session.to_json}
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
      expect(page).to have_css('#title-slide.present')
      expect(page.evaluate_script("document.documentElement.lang")).to eq('de-CH')
      within('#top-left-controls') do
        expect(page).to have_button('🔗 Show QR code')
        expect(page).to have_link('📖 Table of contents')
      end
      within('#top-right-controls') do
        expect(page).to have_button('⚙️ Settings')
      end
      within('#bottom-left-controls') do
        expect(page).to have_css('#multiplex-status-button[aria-haspopup="dialog"]')
      end
      # 🚀 only shows on a song — hidden on the title slide (see '🚀 visibility' below)
      expect(page).not_to have_button('🚀 Live-Scrollen starten')
      expect(page).to have_css('#master-mode', visible: :hidden)

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
      # The Introduction isn't a song and isn't listed.
      expect(all('#TOC a', visible: :all).size).to eq(song_count)

      click_link('Table of contents')
      expect(page).to have_css('#TOC.present')

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
      click_button('⚙️ Settings')
    end

    it 'toggles chord visibility from the settings dialog' do
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
      end

      check('Akkorde anzeigen')
      expect(page).to have_no_css('body.chords-hidden')
      within 'section.slide.present' do
        expect(page).to have_css('code')
        expect(page).to have_no_css('code', visible: :hidden)
      end

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

        # The password survives a reload too, even with no session live —
        # authentication isn't tied to a particular session.
        page.refresh
        wait_for_reveal
        page.evaluate_script("Reveal.slide(3, 0)")
        wait_for_js("Reveal.getIndices().h === 3")
        click_button('🚀 Live-Scrollen starten')
        expect(page).to have_visible('#scroll-choice-modal')
        expect(page).not_to have_visible('#master-modal')
        within('#scroll-choice-modal') { click_button('Abbrechen') }
      end
    end

    describe '🚀 visibility' do
      before { load_presentation }

      it 'shows 🚀 only on a song — hidden on the title, the TOC and the introduction' do
        master_hidden_at = lambda do |h|
          page.evaluate_script("Reveal.slide(#{h}, 0)")
          wait_for_js("Reveal.getIndices().h === #{h}")
          page.evaluate_script("document.getElementById('master-mode').hidden")
        end

        wait_for_js("document.getElementById('master-mode').hidden === true") # title slide on load
        expect(master_hidden_at.call(1)).to be true  # TOC
        expect(master_hidden_at.call(2)).to be true  # Introduction (a stack; its slug sits on the first sub-slide)
        expect(master_hidden_at.call(3)).to be false # the first song
        expect(master_hidden_at.call(1)).to be true  # back off a song
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
          expect(page).to have_css('#multiplex-status-button.multiplex-driving')
          expect(page).not_to have_css('#multiplex-toast.visible', text: 'Es geht gleich los!') # the presenter announces to the room, not to itself
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

        # A reload mid-session restores the role on both sides: no password
        # prompt again for the presenter, and no flash of free navigation for
        # the client while waiting for the next heartbeat to re-establish it.
        # The song (h) is guaranteed by the session restore itself; the exact
        # sub-slide (v) depends on reveal.js's own hash write, which is
        # debounced up to a second behind rapid moves — not asserted here.
        using_session(:presenter) do
          page.refresh
          wait_for_reveal
          expect(page).to have_css('#master-mode.session-active', text: /🚀\s+Live-Scrollen beenden/)
          expect(page).to have_css('#multiplex-status', text: 'Du scrollst live')
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(3)
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

        # Ending drops everyone back on the TOC, frees them, and shows the notice
        using_session(:presenter) do
          click_button('🚀 Live-Scrollen beenden')
          expect(page).to have_no_css('#master-mode.session-active')
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          wait_for_js("Reveal.getIndices().h === 1") # sent to the table of contents
          expect(slide_indices).to eq([1, 0])
          expect(page).to have_link('Table of contents') # free again: 📖 is back
          expect(page).to have_no_css('#multiplex-status-button.multiplex-driving')
        end
        using_session(:client) do
          expect(page).to have_css('#multiplex-toast.visible', text: 'Du kannst jetzt wieder frei navigieren')
          wait_for_js("Reveal.getIndices().h === 1") # every follower lands on the TOC too
          expect(slide_indices).to eq([1, 0])
          expect(page).to have_link('Table of contents')
          expect(page).to have_no_css('#multiplex-status-button.multiplex-following')
          find('body').send_keys(:right) # free to browse again
          wait_for_js("Reveal.getIndices().h === 2")
          expect(page.evaluate_script("Reveal.getIndices().h")).to eq(2)
        end
      end

      it 'guest-scroll: the first volunteer leads the room, is walled into the song, and is thanked when it starts and when it ends' do
        [:guest_a, :guest_b].each do |s|
          using_session(s) { load_presentation; expect(page).to have_css('#title-slide.present') }
        end

        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          start_scroll_session(mode: :guest)
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
          # Delegated to the guest: the presenter now follows too (ring, not dot)
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
        # is stable across a reload, so the presenter's session (still naming
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

      it 'a guest who volunteers but loses the race is told someone else is already scrolling' do
        using_session(:guest) do
          load_presentation
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          install_spy
          spy_send_session({ id: 'spy-1', active: true, song: 4, songTitle: 'Across the universe', mode: 'guest', scrollerId: nil }, fresh: true)
          expect(page).to have_visible('#guest-invite-modal')

          within('#guest-invite-modal') { click_button('Ja, ich scrolle') }
          expect(page).not_to have_visible('#guest-invite-modal')

          spy_send_session({ id: 'spy-1', active: true, song: 4, songTitle: 'Across the universe', mode: 'guest', scrollerId: 'someone-else' })
          expect(page).to have_css('#multiplex-toast.visible', text: 'Oh, das wäre nett gewesen – aber jemand anderes scrollt bereits!')
          expect(page).to have_css('#multiplex-status', text: 'Folgt') # the room still runs; this guest just isn't the one scrolling
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

      it 'the presenter keeps the ability to end the session even if the delegated guest goes silent for a while' do
        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          install_phantom_guest
          wait_for_js("window._phantom && window._phantom.connected")

          # heartbeat: 300, not the usual fast 100/200ms other specs use: the
          # release-checker ticks on a fixed 500ms, independent of cfg.heartbeat
          # (see body-controls.html) — a staleness threshold shorter than that
          # tick (3 * 100 = 300ms < 500ms) can never be observed as "fresh"
          # again, since by the time the next tick runs more than 300ms has
          # always already passed. 3 * 300 = 900ms comfortably clears it.
          start_scroll_session(mode: :guest, heartbeat: 300)
          wait_for_js("window._phantom.sessionId !== null")
          page.execute_script("window._phantomVolunteer()")
          expect(page).to have_css('#multiplex-status', text: 'Gast scrollt')

          # The phantom guest never sends any state at all. Past three missed
          # heartbeats (900ms here) an ordinary follower frees itself — and
          # before the presenter was exempted from that, so did the presenter:
          # the ❌ vanished and 🚀 reverted to "Live-Scrollen starten", even
          # though the guest — and everyone else still locked to it — carried
          # on regardless. A flaky connection to the guest must not cost the
          # presenter its own ability to end the session.
          sleep 1.1
          expect(page).to have_css('#master-mode.session-active', text: /🚀\s+Live-Scrollen beenden/)
          # Told why the view has stopped moving, instead of silently wondering
          expect(page).to have_css('#multiplex-toast.visible',
            text: 'Keine Rückmeldung vom Gast mehr – du kannst die Sitzung bei Bedarf beenden')

          # The guest comes back: told so, once
          page.execute_script("window._phantomState()")
          expect(page).to have_css('#multiplex-toast.visible', text: 'Der Gast ist wieder verbunden')

          click_button('🚀 Live-Scrollen beenden')
          expect(page).to have_no_css('#master-mode.session-active')
          wait_for_js("Reveal.getIndices().h === 1")
          expect(slide_indices).to eq([1, 0])
        end
      end

      it 'shows a toast when the connection drops and when it comes back, on top of the persistent status line' do
        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(3, 0)")
          wait_for_js("Reveal.getIndices().h === 3")
          start_scroll_session(mode: :self)
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

      it 'ending a session repeats the broadcast, so one dropped packet does not strand the room' do
        using_session(:presenter) do
          load_presentation
          page.evaluate_script("Reveal.slide(4, 0)") # Across the universe
          wait_for_js("Reveal.getIndices().h === 4")
          start_scroll_session(mode: :self)
          install_spy
          page.execute_script(<<~JS)
            window._endMessages = [];
            window._spy.on(window.MULTIPLEX.socketId, function(data) {
              if (data && data.type === 'session' && data.session && data.session.active === false) {
                window._endMessages.push(Date.now());
              }
            });
          JS

          click_button('🚀 Live-Scrollen beenden')
          sleep 1.2 # past the retries' 1s spread
          expect(page.evaluate_script('window._endMessages.length')).to be >= 2
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
          expect(page).not_to have_css('#multiplex-toast.visible', text: 'Es geht gleich los!') # joined mid-session: no announcement
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
        expect(page).to have_css('#multiplex-info-status', text: 'Kein Live-Scrollen aktiv')

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
