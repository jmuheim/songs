require 'capybara/rspec'

RSpec.describe 'index.html', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  # Standard setup shared by most groups
  def load_presentation
    visit '/index.html'
    wait_for_reveal
  end

  # -----------------------------------------------------------------------
  # Structure & initial state
  # -----------------------------------------------------------------------
  describe 'structure' do
    before { load_presentation }

    it 'renders the title slide as the initial visible slide' do
      expect(page).to have_css('#title-slide.present')
    end

    it 'shows the song book title on the title slide' do
      expect(find('#title-slide')).to have_text('Lieblings-Songs')
    end

    it 'shows the authors on the title slide' do
      expect(find('#title-slide')).to have_text('Josua')
    end

    it 'has a TOC section in the DOM with links to all songs' do
      toc = first('#TOC', visible: :all)
      expect(toc).not_to be_nil
      expect(toc.all('a', visible: :all).size).to be >= 5
    end

    it 'lists ABBA in the TOC' do
      expect(first('#TOC', visible: :all).text(:all)).to include('ABBA')
    end

    it 'has chord code elements in the DOM with color CSS classes' do
      chord_codes = all('section code', visible: :all).select { |el| el[:class]&.match?(/\A[a-g]\z/) }
      expect(chord_codes).not_to be_empty
    end

    it 'has the master mode button (#master-mode)' do
      expect(page).to have_css('#master-mode')
    end

    it 'has the QR code button (#show-qr)' do
      expect(page).to have_css('#show-qr')
    end

    it 'has the chord visibility toggle button (#toggle-chords-visibility)' do
      expect(page).to have_css('#toggle-chords-visibility')
    end

    it 'wraps slide content in .slide-content divs' do
      expect(page).to have_css('.slide-content', visible: :all)
    end

    it 'uses the night theme (dark background)' do
      bg = page.evaluate_script(
        "getComputedStyle(document.querySelector('.reveal') || document.body).backgroundColor"
      )
      expect(bg.scan(/\d+/).map(&:to_i).sum).to be < 150
    end

    it 'has the multiplex config embedded as a window global' do
      socket_id = page.evaluate_script("window.MULTIPLEX && window.MULTIPLEX.socketId")
      expect(socket_id).not_to be_nil
      expect(socket_id).not_to be_empty
    end

    it 'Reveal.js reports total slide count' do
      song_count = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].size
      expect(page.evaluate_script("Reveal.getTotalSlides()")).to be > song_count
    end
  end

  # -----------------------------------------------------------------------
  # Slide navigation via Reveal.js API
  # -----------------------------------------------------------------------
  describe 'slide navigation' do
    before { load_presentation }

    it 'can navigate to the next horizontal slide via Reveal.js API' do
      initial_h = page.evaluate_script("Reveal.getIndices().h")
      page.evaluate_script("Reveal.right()")
      sleep 0.3
      expect(page.evaluate_script("Reveal.getIndices().h")).to be > initial_h
    end

    it 'can navigate to a sub-slide (vertical) via Reveal.js API' do
      page.evaluate_script("Reveal.slide(2, 0)")
      sleep 0.3
      page.evaluate_script("Reveal.down()")
      sleep 0.3
      expect(page.evaluate_script("Reveal.getIndices().v")).to be > 0
    end
  end

  # -----------------------------------------------------------------------
  # Slide zoom (style/slide-zoom.js)
  # -----------------------------------------------------------------------
  describe 'slide zoom' do
    before { load_presentation }

    it 'sets a zoom value on the title slide .slide-content' do
      zoom = page.evaluate_script(
        "document.querySelector('#title-slide .slide-content')?.style?.zoom"
      )
      expect(zoom.to_s).not_to be_empty
      expect(zoom.to_f).to be > 0
    end

    it 'applies zoom via Reveal.getCurrentSlide() on active sub-slides' do
      page.evaluate_script("Reveal.slide(2, 1)")
      sleep 0.4
      zoom = page.evaluate_script(
        "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom"
      )
      expect(zoom.to_f).to be > 0
    end

    it 'keeps zoom positive after navigating between slides' do
      [0, 2, 3].each do |h|
        page.evaluate_script("Reveal.slide(#{h}, 0)")
        sleep 0.2
        zoom = page.evaluate_script(
          "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom"
        )
        expect(zoom.to_f).to be > 0, "Expected zoom > 0 at h=#{h}, got #{zoom.inspect}"
      end
    end

    it 'recalculates zoom on window resize' do
      zoom_before = page.evaluate_script(
        "parseFloat(document.querySelector('#title-slide .slide-content')?.style?.zoom || '0')"
      )
      page.driver.browser.resize(width: 480, height: 600)
      sleep 0.2
      page.evaluate_script("window.dispatchEvent(new Event('resize'))")
      sleep 0.2
      zoom_after = page.evaluate_script(
        "parseFloat(document.querySelector('#title-slide .slide-content')?.style?.zoom || '0')"
      )
      expect(zoom_after).to be > 0
      expect(zoom_after).not_to eq(zoom_before)
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end

    it 'does not zoom beyond what fits the viewport' do
      zoom = page.evaluate_script(
        "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom"
      ).to_f
      return if zoom.zero?

      content_w = page.evaluate_script("Reveal.getCurrentSlide()?.querySelector('.slide-content')?.scrollWidth").to_f
      content_h = page.evaluate_script("Reveal.getCurrentSlide()?.querySelector('.slide-content')?.scrollHeight").to_f
      win_w     = page.evaluate_script("window.innerWidth").to_f
      win_h     = page.evaluate_script("window.innerHeight").to_f

      expect(content_w * zoom).to be <= win_w + 2
      expect(content_h * zoom).to be <= win_h + 2
    end
  end

  # -----------------------------------------------------------------------
  # TOC navigation
  # -----------------------------------------------------------------------
  describe 'TOC navigation' do
    before { load_presentation }

    it '#go-to-toc link points to slide index 1 (#/1)' do
      expect(page.evaluate_script("document.getElementById('go-to-toc').getAttribute('href')")).to eq('#/1')
    end

    it 'clicking #go-to-toc navigates to horizontal slide 1 (the TOC)' do
      click_link('Table of contents')
      sleep 0.5
      expect(page.evaluate_script("Reveal.getIndices().h")).to eq(1)
    end

    it 'TOC slide becomes the present slide after clicking #go-to-toc' do
      click_link('Table of contents')
      sleep 0.5
      expect(page.evaluate_script("document.querySelector('.present')?.id || ''")).to eq('TOC')
    end

    it 'TOC contains a link for every active song plus the introduction' do
      song_count = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].size
      expect(all('#TOC a', visible: :all).size).to eq(song_count + 1)
    end

    it 'clicking a TOC song link navigates to that song slide' do
      click_link('Table of contents')
      sleep 0.5
      first('#TOC a', visible: :all).click
      sleep 0.5
      expect(page.evaluate_script("Reveal.getIndices().h")).to be >= 2
    end

    it 'the TOC lists all expected song titles' do
      toc_text = first('#TOC', visible: :all).text(:all)
      %w[ABBA Beatles Lennon].each do |artist|
        expect(toc_text).to include(artist)
      end
    end
  end

  # -----------------------------------------------------------------------
  # Chord visibility toggle
  # -----------------------------------------------------------------------
  describe 'chord visibility toggle' do
    before do
      load_presentation
      page.evaluate_script("Reveal.slide(2, 1)")
      sleep 0.3
    end

    def chord_display
      page.evaluate_script(
        "getComputedStyle(document.querySelector('section.present code') || document.querySelector('section code')).display"
      )
    end

    it 'shows chords initially (display is not none)' do
      expect(page.evaluate_script("document.body.classList.contains('chords-hidden')")).to be false
      expect(chord_display).not_to eq('none')
    end

    it 'hides chord code elements after one click on the toggle button' do
      click_button('Toggle chord visibility')
      sleep 0.2
      expect(page.evaluate_script("document.body.classList.contains('chords-hidden')")).to be true
      expect(chord_display).to eq('none')
    end

    it 'shows chords again after a second click (toggle back)' do
      click_button('Toggle chord visibility')
      sleep 0.2
      click_button('Toggle chord visibility')
      sleep 0.2
      expect(page.evaluate_script("document.body.classList.contains('chords-hidden')")).to be false
      expect(chord_display).not_to eq('none')
    end

    it 'toggle button blurs itself after click (does not steal keyboard focus)' do
      click_button('Toggle chord visibility')
      sleep 0.2
      expect(page.evaluate_script("document.activeElement?.id || ''")).not_to eq('toggle-chords-visibility')
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

    it 'starts in dark (night) theme with no theme-bright class' do
      expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be false
      expect(bg_brightness).to be < 150
    end

    it 'switches to bright theme after clicking #toggle-theme' do
      click_link('Toggle theme')
      sleep 0.2
      expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be true
      expect(bg_brightness).to be > 500
    end

    it 'switches back to dark theme on a second click' do
      click_link('Toggle theme')
      sleep 0.2
      click_link('Toggle theme')
      sleep 0.2
      expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be false
    end

    it 'persists the bright theme preference in localStorage' do
      click_link('Toggle theme')
      sleep 0.2
      expect(page.evaluate_script("localStorage.getItem('theme')")).to eq('bright')
    end

    it 'persists the dark theme preference in localStorage after toggling back' do
      click_link('Toggle theme')
      sleep 0.2
      click_link('Toggle theme')
      sleep 0.2
      expect(page.evaluate_script("localStorage.getItem('theme')")).to eq('dark')
    end

    it 'restores the bright theme on page reload when localStorage says bright' do
      click_link('Toggle theme')
      sleep 0.2
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

    def modal_visible?(id)
      page.evaluate_script("document.getElementById('#{id}').classList.contains('visible')")
    end

    def io_available?
      page.evaluate_script("typeof window.io === 'function'")
    end

    it 'master modal is hidden on load' do
      expect(modal_visible?('master-modal')).to be false
    end

    it 'QR modal is hidden on load' do
      expect(modal_visible?('qr-modal')).to be false
    end

    it 'master modal has a password input field' do
      expect(page).to have_css('#master-pw[type="password"]', visible: :all)
    end

    it 'master modal has Cancel and OK buttons' do
      expect(page).to have_css('#master-cancel', visible: :all)
      expect(page).to have_css('#master-confirm', visible: :all)
    end

    context 'when socket.io is loaded' do
      before { skip 'socket.io not available' unless io_available? }

      it 'opens the master modal on #master-mode click' do
        click_button('Take over presentation control')
        sleep 0.2
        expect(modal_visible?('master-modal')).to be true
      end

      it 'closes the master modal when Cancel is clicked' do
        click_button('Take over presentation control')
        sleep 0.2
        click_button('Cancel')
        sleep 0.2
        expect(modal_visible?('master-modal')).to be false
      end

      it 'clears the password input on cancel' do
        click_button('Take over presentation control')
        sleep 0.2
        find('#master-pw').set('something')
        click_button('Cancel')
        sleep 0.2
        expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
      end

      it 'adds the shake class briefly on wrong password' do
        click_button('Take over presentation control')
        sleep 0.2
        find('#master-pw').set('wrongpassword')
        click_button('OK')
        sleep 0.1
        expect(page.evaluate_script("document.getElementById('master-pw').classList.contains('shake')")).to be true
      end

      it 'clears the input on wrong password' do
        click_button('Take over presentation control')
        sleep 0.2
        find('#master-pw').set('wrongpassword')
        click_button('OK')
        sleep 0.6
        expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
      end

      it 'keeps the modal open after wrong password' do
        click_button('Take over presentation control')
        sleep 0.2
        find('#master-pw').set('wrongpassword')
        click_button('OK')
        sleep 0.2
        expect(modal_visible?('master-modal')).to be true
      end

      it 'grants master mode and closes modal on correct password' do
        password = page.evaluate_script("window.MULTIPLEX.password")
        click_button('Take over presentation control')
        sleep 0.2
        find('#master-pw').set(password)
        click_button('OK')
        sleep 0.3
        expect(modal_visible?('master-modal')).to be false
        expect(page.evaluate_script("document.getElementById('master-mode').classList.contains('is-master')")).to be true
      end

      it 'closes the master modal when clicking outside it' do
        click_button('Take over presentation control')
        sleep 0.2
        page.execute_script("document.getElementById('master-modal').click()")
        sleep 0.2
        expect(modal_visible?('master-modal')).to be false
      end

      it 'opens the QR modal on #show-qr click' do
        click_button('Show QR code')
        sleep 0.3
        expect(modal_visible?('qr-modal')).to be true
      end

      it 'closes the QR modal on close button click' do
        click_button('Show QR code')
        sleep 0.3
        click_button('Schliessen')
        sleep 0.2
        expect(modal_visible?('qr-modal')).to be false
      end

      it 'closes the QR modal when clicking outside it' do
        click_button('Show QR code')
        sleep 0.3
        page.execute_script("document.getElementById('qr-modal').click()")
        sleep 0.2
        expect(modal_visible?('qr-modal')).to be false
      end
    end
  end
end
