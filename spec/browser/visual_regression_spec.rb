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

  before do
    page.driver.browser.resize(width: 1280, height: 800)
  end

  after do
    page.evaluate_script('localStorage.clear()') rescue nil
  end

  def load_presentation
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
  end

  def load_print_presentation
    visit FixtureBuilder::PRINT_URL_PATH
    wait_for_reveal
  end

  def go_to_first_song
    page.evaluate_script('Reveal.slide(3, 1)')
    wait_for_js('Reveal.getIndices().h === 3 && Reveal.getIndices().v === 1')
  end

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
end
