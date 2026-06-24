require 'capybara/rspec'

# Visual regression tests — baselines live in spec/screenshots/*.png (committed).
#
# First run saves the baselines; tests pass. Commit the PNGs, then subsequent
# runs compare against them. To update a single baseline after an intentional
# change: rm spec/screenshots/<name>.png, then run that example again.

RSpec.describe 'visual regression', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  after do
    page.evaluate_script('localStorage.clear(); sessionStorage.clear()') rescue nil
  end

  # Resize happens here, immediately before visit, so the page always loads
  # at the intended viewport and slide-zoom.js computes a stable zoom value.
  def load_presentation(width: 1280, height: 800)
    page.driver.browser.resize(width: width, height: height)
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
  end

  def load_print_presentation
    page.driver.browser.resize(width: 1280, height: 800)
    visit FixtureBuilder::PRINT_URL_PATH
    wait_for_reveal
  end

  def go_to_first_song
    page.evaluate_script('Reveal.slide(3, 1)')
    wait_for_js('Reveal.getIndices().h === 3 && Reveal.getIndices().v === 1')
    # slide-zoom.js sets zoom asynchronously via the slidechanged event.
    # Wait for it to finish before screenshotting (zoom value is a float, not "1").
    wait_for_js("document.querySelector('section.present .slide-content')?.style?.zoom?.includes('.')")
  end

  # ---------------------------------------------------------------------------
  # Desktop (1280×800) — no breakpoints active
  # ---------------------------------------------------------------------------

  it 'title slide — initial load' do
    load_presentation
    expect(page).to have_css('#title-slide.present')
    screenshot 'title_slide'
  end

  it 'table of contents slide' do
    load_presentation
    page.evaluate_script('Reveal.slide(1, 0)')
    wait_for_js('Reveal.getIndices().h === 1')
    expect(page).to have_css('#TOC.present')
    screenshot 'toc_slide'
  end

  it 'song slide — first verse' do
    load_presentation
    go_to_first_song
    expect(page).to have_css('section.present.level2')
    screenshot 'song_slide_verse'
  end

  it 'song slide — chords hidden' do
    load_presentation
    go_to_first_song
    click_button('🎹 Hide chords')
    expect(page).to have_css('body.chords-hidden')
    screenshot 'song_slide_chords_hidden'
  end

  it 'title slide — bright theme' do
    load_presentation
    click_button('🌞 Switch to bright mode')
    expect(page).to have_css('body.theme-bright')
    screenshot 'title_slide_bright_theme'
  end

  it 'print.html — title slide' do
    load_print_presentation
    expect(page).to have_css('#title-slide.present')
    screenshot 'print_title_slide'
  end

  # ---------------------------------------------------------------------------
  # Viewport breakpoints
  # @media (max-width: 768px) { section#TOC { font-size: 0.75em } }
  #
  # Song slides are omitted here: no breakpoint-specific CSS affects them,
  # and slide-zoom.js computes fractional zoom that would cause flaky diffs.
  # ---------------------------------------------------------------------------

  describe 'at 768px wide — breakpoint applies' do
    it 'title slide' do
      load_presentation(width: 768)
      expect(page).to have_css('#title-slide.present')
      screenshot 'bp768_title_slide'
    end

    it 'TOC slide' do
      load_presentation(width: 768)
      page.evaluate_script('Reveal.slide(1, 0)')
      wait_for_js('Reveal.getIndices().h === 1')
      expect(page).to have_css('#TOC.present')
      screenshot 'bp768_toc_slide'
    end
  end

  describe 'at 769px wide — breakpoint does not apply' do
    it 'title slide' do
      load_presentation(width: 769)
      expect(page).to have_css('#title-slide.present')
      screenshot 'bp769_title_slide'
    end

    it 'TOC slide' do
      load_presentation(width: 769)
      page.evaluate_script('Reveal.slide(1, 0)')
      wait_for_js('Reveal.getIndices().h === 1')
      expect(page).to have_css('#TOC.present')
      screenshot 'bp769_toc_slide'
    end
  end
end
