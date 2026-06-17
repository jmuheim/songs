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

      # title-slide + TOC + Introduction + 4 fixture songs
      expect(all('.slides > section', visible: :all).size).to eq(7)
    end
  end

  # -----------------------------------------------------------------------
  # Slide navigation via Reveal.js API
  # -----------------------------------------------------------------------
  describe 'slide navigation' do
    before { load_presentation }

    it 'can navigate horizontally and vertically via Reveal.js API' do
      initial_h = page.evaluate_script("Reveal.getIndices().h")
      page.evaluate_script("Reveal.right()")
      wait_for_js("Reveal.getIndices().h > #{initial_h}")
      expect(page.evaluate_script("Reveal.getIndices().h")).to be > initial_h

      page.evaluate_script("Reveal.slide(2, 0)")
      wait_for_js("Reveal.getIndices().h === 2")
      page.evaluate_script("Reveal.down()")
      wait_for_js("Reveal.getIndices().v > 0")
      expect(page.evaluate_script("Reveal.getIndices().v")).to be > 0
    end
  end

  # -----------------------------------------------------------------------
  # Slide zoom (style/slide-zoom.js)
  # -----------------------------------------------------------------------
  describe 'slide zoom' do
    before { load_presentation }

    it 'applies and maintains positive zoom across slides without exceeding the viewport' do
      zoom = page.evaluate_script(
        "document.querySelector('#title-slide .slide-content')?.style?.zoom"
      )
      expect(zoom.to_s).not_to be_empty
      expect(zoom.to_f).to be > 0

      page.evaluate_script("Reveal.slide(2, 1)")
      wait_for_js("parseFloat(Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom || 0) > 0")
      expect(page.evaluate_script("Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom").to_f).to be > 0

      [0, 2, 3].each do |h|
        page.evaluate_script("Reveal.slide(#{h}, 0)")
        wait_for_js("parseFloat(Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom || 0) > 0")
        zoom = page.evaluate_script("Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom")
        expect(zoom.to_f).to be > 0, "Expected zoom > 0 at h=#{h}, got #{zoom.inspect}"
      end

      zoom = page.evaluate_script("Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom").to_f
      unless zoom.zero?
        content_w = page.evaluate_script("Reveal.getCurrentSlide()?.querySelector('.slide-content')?.scrollWidth").to_f
        content_h = page.evaluate_script("Reveal.getCurrentSlide()?.querySelector('.slide-content')?.scrollHeight").to_f
        win_w     = page.evaluate_script("window.innerWidth").to_f
        win_h     = page.evaluate_script("window.innerHeight").to_f
        expect(content_w * zoom).to be <= win_w + 2
        expect(content_h * zoom).to be <= win_h + 2
      end
    end

    it 'recalculates zoom on window resize' do
      zoom_before = page.evaluate_script(
        "parseFloat(document.querySelector('#title-slide .slide-content')?.style?.zoom || '0')"
      )
      page.driver.browser.resize(width: 480, height: 600)
      page.evaluate_script("window.dispatchEvent(new Event('resize'))")
      wait_for_js(
        "parseFloat(document.querySelector('#title-slide .slide-content')?.style?.zoom || '0') !== #{zoom_before}"
      )
      zoom_after = page.evaluate_script(
        "parseFloat(document.querySelector('#title-slide .slide-content')?.style?.zoom || '0')"
      )
      expect(zoom_after).to be > 0
      expect(zoom_after).not_to eq(zoom_before)
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end
  end

  # -----------------------------------------------------------------------
  # TOC navigation
  # -----------------------------------------------------------------------
  describe 'TOC navigation' do
    before { load_presentation }

    it 'has correct TOC structure' do
      expect(page.evaluate_script("document.getElementById('go-to-toc').getAttribute('href')")).to eq('#/1')

      song_count = Dir[File.join(FixtureBuilder::SONGS_DIR, '*.md')].size
      expect(all('#TOC a', visible: :all).size).to eq(song_count + 1)
    end

    it 'clicking TOC links navigates correctly' do
      click_link('Table of contents')
      expect(page).to have_css('#TOC.present')
      expect(page.evaluate_script("Reveal.getIndices().h")).to eq(1)

      first('#TOC a', visible: :all).click
      expect(page).to have_no_css('#TOC.present')
      expect(page.evaluate_script("Reveal.getIndices().h")).to be >= 2
    end
  end

  # -----------------------------------------------------------------------
  # Chord visibility toggle
  # -----------------------------------------------------------------------
  describe 'chord visibility toggle' do
    before do
      load_presentation
      page.evaluate_script("Reveal.slide(2, 1)")
      wait_for_js("Reveal.getIndices().h === 2 && Reveal.getIndices().v === 1")
    end

    def chord_display
      page.evaluate_script(
        "getComputedStyle(document.querySelector('section.present code') || document.querySelector('section code')).display"
      )
    end

    it 'shows chords initially and hides them on toggle without stealing focus' do
      expect(page.evaluate_script("document.body.classList.contains('chords-hidden')")).to be false
      expect(chord_display).not_to eq('none')
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="false"]')

      click_button('Hide chords')
      expect(page).to have_css('body.chords-hidden')
      expect(chord_display).to eq('none')
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="true"]')
      expect(page.evaluate_script("document.activeElement?.id || ''")).not_to eq('toggle-chords-visibility')
    end

    it 'shows chords again after a second click (toggle back)' do
      click_button('Hide chords')
      expect(page).to have_css('body.chords-hidden')
      click_button('Hide chords')
      expect(page).to have_no_css('body.chords-hidden')
      expect(page).to have_css('#toggle-chords-visibility[aria-pressed="false"]')
      expect(chord_display).not_to eq('none')
    end
  end

  # -----------------------------------------------------------------------
  # Theme toggle
  # -----------------------------------------------------------------------
  describe 'theme toggle' do
    def bg_brightness
      hex = page.evaluate_script(
        "getComputedStyle(document.body).getPropertyValue('--r-background-color').trim()"
      ).gsub(/[^0-9a-fA-F]/, '')
      hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3
      (hex[0..1]&.to_i(16) || 0) + (hex[2..3]&.to_i(16) || 0) + (hex[4..5]&.to_i(16) || 0)
    end

    before do
      visit '/index.html'
      page.evaluate_script("localStorage.removeItem('theme')")
      visit '/index.html'
      wait_for_reveal
    end

    it 'starts dark, switches to bright, and persists the preference' do
      expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be false
      expect(bg_brightness).to be < 150
      expect(page).to have_button('🌞 Switch to bright mode')
      expect(page).to have_css('#toggle-theme[aria-pressed="false"]')

      click_button('Switch to bright mode')
      expect(page).to have_css('body.theme-bright')
      expect(bg_brightness).to be > 500
      expect(page.evaluate_script("localStorage.getItem('theme')")).to eq('bright')
      expect(page).to have_button('🌛 Switch to dark mode')
      expect(page).to have_css('#toggle-theme[aria-pressed="true"]')
    end

    it 'switches back to dark on a second click and persists the preference' do
      click_button('Switch to bright mode')
      expect(page).to have_css('body.theme-bright')
      click_button('Switch to dark mode')
      expect(page).to have_no_css('body.theme-bright')
      expect(page.evaluate_script("localStorage.getItem('theme')")).to eq('dark')
    end

    it 'restores the bright theme on page reload when localStorage says bright' do
      click_button('Switch to bright mode')
      expect(page).to have_css('body.theme-bright')
      visit '/index.html'
      wait_for_reveal
      expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be true
    end
  end

  # -----------------------------------------------------------------------
  # Multiplex UI (master modal & QR modal)
  # -----------------------------------------------------------------------
  describe 'multiplex UI' do
    before { load_presentation }

    def io_available?
      page.evaluate_script("typeof window.io === 'function'")
    end

    it 'has the correct initial modal structure' do
      expect(page).to have_no_css('#master-modal.visible')
      expect(page).to have_no_css('#qr-modal.visible')
      expect(page).to have_css('#master-mode[aria-pressed="false"]')
      expect(page).to have_css('#show-qr[aria-pressed="false"]')
      expect(page).to have_css('#master-pw[type="password"]', visible: :all)
      expect(page).to have_css('#master-cancel', visible: :all)
      expect(page).to have_css('#master-confirm', visible: :all)
    end

    context 'when socket.io is loaded' do
      before { skip 'socket.io not available' unless io_available? }

      it 'opens and closes the master modal' do
        click_button('Lead slide navigation')
        expect(page).to have_css('#master-modal.visible')
        page.execute_script("document.getElementById('master-modal').click()")
        expect(page).to have_no_css('#master-modal.visible')
      end

      it 'Cancel clears the password input and closes the modal' do
        click_button('Lead slide navigation')
        expect(page).to have_css('#master-modal.visible')
        find('#master-pw').set('something')
        click_button('Cancel')
        expect(page).to have_no_css('#master-modal.visible')
        expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
      end

      it 'rejects wrong password with shake, clears input, and keeps modal open' do
        click_button('Lead slide navigation')
        find('#master-pw').set('wrongpassword')
        click_button('OK')
        expect(page).to have_css('#master-pw.shake')
        expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
        expect(page).to have_css('#master-modal.visible')
      end

      it 'grants master mode on correct password and manages the QR modal' do
        password = page.evaluate_script("window.MULTIPLEX.password")
        click_button('Lead slide navigation')
        find('#master-pw').set(password)
        click_button('OK')
        expect(page).to have_no_css('#master-modal.visible')
        expect(page).to have_css('#master-mode.is-master')
        expect(page).to have_css('#master-mode[aria-pressed="true"]')

        click_button('Show QR code')
        expect(page).to have_css('#qr-modal.visible')
        expect(page).to have_css('#show-qr[aria-pressed="true"]')
        click_button('Schliessen')
        expect(page).to have_no_css('#qr-modal.visible')
        expect(page).to have_css('#show-qr[aria-pressed="false"]')

        click_button('Show QR code')
        expect(page).to have_css('#qr-modal.visible')
        page.execute_script("document.getElementById('qr-modal').click()")
        expect(page).to have_no_css('#qr-modal.visible')
        expect(page).to have_css('#show-qr[aria-pressed="false"]')
      end
    end
  end
end
