require 'capybara/rspec'

RSpec.describe 'index.html', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  # Standard setup shared by most groups
  def load_presentation
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
  end

  def go_to_first_song
    page.evaluate_script("Reveal.slide(3, 1)")
    wait_for_js("Reveal.getIndices().h === 3 && Reveal.getIndices().v === 1")
  end

  def backdrop_click(id)
    page.execute_script("document.getElementById('#{id}').click()") # e.target must be the overlay, not a child
  end

  # -----------------------------------------------------------------------
  # Structure & initial state
  # -----------------------------------------------------------------------
  describe 'structure' do
    before { load_presentation }

    it 'has the correct DOM structure and initial state' do
      expect(page).to have_css('#title-slide.present')
      within('#top-left-controls') do
        expect(page).to have_link('📖 Table of contents')
        expect(page).to have_button('🎹 Hide chords')
      end
      within('#top-right-controls') do
        expect(page).to have_button('🔗 Show QR code')
        expect(page).to have_button('🚀 Lead slide navigation')
        expect(page).to have_button('🌞 Switch to bright mode')
      end

      socket_id = page.evaluate_script("window.MULTIPLEX && window.MULTIPLEX.socketId")
      expect(socket_id).not_to be_nil
      expect(socket_id).not_to be_empty

      # title-slide + TOC + Introduction + fixture songs
      expect(all('.slides > section', visible: :all).size).to eq(3 + song_count)
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
      expect(page).to have_css('#title-slide .slide-content[style="zoom: 1.41436;"]', visible: :all)

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
    end
  end

  # -----------------------------------------------------------------------
  # Multiplex
  # -----------------------------------------------------------------------
  describe 'multiplex' do
    describe 'master modal' do
      before { load_presentation }

      it 'dismisses on outside click, cancel clears input, wrong password shakes, correct password activates master' do
        expect(page).not_to have_visible('#master-modal')
        expect(page).to have_css('#master-mode[aria-pressed="false"]', text: /🚀\s+Lead slide navigation/)

        click_button('🚀 Lead slide navigation')
        expect(page).to have_visible('#master-modal')
        backdrop_click('master-modal')
        expect(page).not_to have_visible('#master-modal')

        click_button('🚀 Lead slide navigation')
        within('#master-modal') do
          find('#master-pw').set('something')
          click_button('Cancel')
        end
        expect(page).not_to have_visible('#master-modal')
        expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty

        click_button('🚀 Lead slide navigation')
        within('#master-modal') do
          find('#master-pw').set('wrongpassword')
          click_button('OK')
          expect(page).to have_css('#master-pw.shake')
          expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
        end
        expect(page).to have_visible('#master-modal')

        within('#master-modal') do
          find('#master-pw').set(page.evaluate_script("window.MULTIPLEX.password"))
          click_button('OK')
        end
        expect(page).not_to have_visible('#master-modal')
        expect(page).to have_css('#master-mode.is-master')
        expect(page).to have_css('#master-mode[aria-pressed="true"]', text: /🚀\s+Lead slide navigation/)
      end
    end

    describe 'live sync' do
      after { Capybara.reset_sessions! }

      it 'client follows slide changes broadcast by the master' do
        using_session(:client) do
          load_presentation
          expect(page).to have_css('#title-slide.present')
        end

        using_session(:master) do
          load_presentation
          click_button('🚀 Lead slide navigation')
          within('#master-modal') do
            find('#master-pw').set(page.evaluate_script("window.MULTIPLEX.password"))
            click_button('OK')
          end
          expect(page).to have_css('#master-mode.is-master')
          find('body').send_keys(:right)
          expect(page).to have_css('#TOC.present')
        end

        using_session(:client) { expect(page).to have_css('#TOC.present') }
      end
    end

    describe 'QR modal' do
      before { load_presentation }

      it 'dismisses on close button and outside click' do
        expect(page).not_to have_visible('#qr-modal')
        expect(page).to have_css('#show-qr[aria-pressed="false"]')

        click_button('Show QR code')
        expect(page).to have_visible('#qr-modal')
        expect(page).to have_css('#show-qr[aria-pressed="true"]')
        within(find('#qr-modal', visible: :all)) { click_button('Schliessen') }
        expect(page).not_to have_visible('#qr-modal')
        expect(page).to have_css('#show-qr[aria-pressed="false"]')

        click_button('Show QR code')
        expect(page).to have_visible('#qr-modal')
        backdrop_click('qr-modal')
        expect(page).not_to have_visible('#qr-modal')
        expect(page).to have_css('#show-qr[aria-pressed="false"]')
      end
    end

  end
end
