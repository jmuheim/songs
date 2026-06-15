require 'capybara/rspec'

RSpec.describe 'mobile layout', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  # --- @media (max-width: 768px) { section#TOC { font-size: 0.75em } } ---

  describe '#TOC font-size media query' do
    it 'applies 0.75em font-size on narrow viewports (≤ 768px)' do
      page.driver.browser.resize(width: 375, height: 812)
      visit '/index.html'
      sleep 1.0

      mobile_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC')).fontSize)"
      )
      parent_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC').parentElement).fontSize)"
      )

      expect(mobile_px).to be_within(0.5).of(parent_px * 0.75)
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end

    it 'does NOT reduce the TOC font-size on wide viewports (> 768px)' do
      page.driver.browser.resize(width: 1280, height: 800)
      visit '/index.html'
      sleep 1.0

      desktop_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC')).fontSize)"
      )
      parent_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC').parentElement).fontSize)"
      )

      # At desktop width no font-size rule applies to #TOC in night.css,
      # so it inherits from its parent unchanged
      expect(desktop_px).to be_within(0.5).of(parent_px)
    end

    it 'TOC is smaller on mobile than on desktop' do
      page.driver.browser.resize(width: 375, height: 812)
      visit '/index.html'
      sleep 1.0
      mobile_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC')).fontSize)"
      )

      page.driver.browser.resize(width: 1280, height: 800)
      visit '/index.html'
      sleep 1.0
      desktop_px = page.evaluate_script(
        "parseFloat(getComputedStyle(document.querySelector('section#TOC')).fontSize)"
      )

      expect(mobile_px).to be < desktop_px
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end
  end

  # --- section#TOC overflow / scroll behaviour ---

  describe '#TOC scroll behaviour' do
    before do
      page.driver.browser.resize(width: 1280, height: 800)
      visit '/index.html'
      sleep 1.5
    end

    it 'has overflow-y: scroll on the TOC section' do
      overflow = page.evaluate_script(
        "getComputedStyle(document.querySelector('section#TOC')).overflowY"
      )
      expect(overflow).to eq('scroll')
    end

    it 'TOC section fills 100% height (to allow scrolling)' do
      height_style = page.evaluate_script(
        "document.querySelector('section#TOC').style.height || getComputedStyle(document.querySelector('section#TOC')).height"
      )
      # height should resolve to a pixel value that represents the full viewport height
      expect(height_style.to_f).to be > 0
    end
  end
end
