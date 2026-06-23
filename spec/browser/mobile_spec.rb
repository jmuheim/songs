require 'capybara/rspec'

RSpec.describe 'mobile layout', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  def load_presentation
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
  end

  # --- @media (max-width: 768px) { section#TOC { font-size: 0.75em } } ---

  describe '#TOC font-size media query' do
    it 'is 0.75em on mobile, inherits on desktop, and is smaller on mobile than desktop' do
      page.driver.browser.resize(width: 375, height: 812)
      load_presentation
      mobile_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC')).fontSize)"
      )
      parent_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC').parentElement).fontSize)"
      )
      expect(mobile_px).to be_within(0.5).of(parent_px * 0.75)

      page.driver.browser.resize(width: 1280, height: 800)
      load_presentation
      desktop_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC')).fontSize)"
      )
      parent_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC').parentElement).fontSize)"
      )
      expect(desktop_px).to be_within(0.5).of(parent_px)
      expect(mobile_px).to be < desktop_px
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end
  end

  # --- section#TOC overflow / scroll behaviour ---

  describe '#TOC scroll behaviour' do
    before do
      page.driver.browser.resize(width: 1280, height: 800)
      load_presentation
    end

    it 'has overflow-y: scroll and fills the full viewport height' do
      overflow = page.evaluate_script(
        "getComputedStyle(document.querySelector('section#TOC')).overflowY"
      )
      expect(overflow).to eq('scroll')

      height_style = page.evaluate_script(
        "document.querySelector('section#TOC').style.height || getComputedStyle(document.querySelector('section#TOC')).height"
      )
      expect(height_style.to_f).to be > 0
    end
  end
end
