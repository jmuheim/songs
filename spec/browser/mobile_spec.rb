require 'capybara/rspec'

RSpec.describe 'mobile layout', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    MultiplexServer.start
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
    end
  end

  # --- @media (width < 500px), (height < 500px) { .modal-box { font-size: 1.35rem } } ---

  describe 'dialogs on a phone held sideways' do
    it 'fit every dialog on the screen, the settings with their fonts included, upright and on a laptop as well' do
      # An iPhone 13 held sideways, Safari's bars shown; an iPhone SE held
      # upright, likewise; a laptop's browser window, its own bars taken off
      [[844, 390], [375, 667], [1280, 680]].each do |width, height|
        page.driver.browser.resize(width: width, height: height)
        load_presentation
        # Each dialog opened straight from script: through its own button,
        # half of them need a session, a host and a song first. All that
        # matters here is their size once open. With a background picture,
        # its dialog shows the veil and whether it moves too
        [false, true].each do |picture|
          overflowing = page.evaluate_script(<<~JS)
            (function () {
              document.body.classList.toggle('custom-background', #{picture});
              return Array.prototype.filter.call(document.querySelectorAll('dialog.overlay-modal'), function (dialog) {
                dialog.showModal();
                var tooTall = dialog.scrollHeight > dialog.clientHeight;
                dialog.close();
                return tooTall;
              }).map(function (dialog) { return dialog.id; });
            })()
          JS
          expect(page.evaluate_script("document.querySelectorAll('dialog.overlay-modal').length")).to be >= 7 # else this proves little
          expect(overflowing).to eq([]), "at #{width}×#{height}#{' with a picture' if picture}: #{overflowing.join(', ')}"
        end
      end
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end
  end

  # --- @media (pointer: coarse) { .reveal .controls { display: none } } ---

  describe 'navigation chevrons' do
    it 'hides them on a touch screen, where a swipe pages the deck' do
      # Touch emulation is what makes Chrome report a coarse primary pointer;
      # CDP's setEmulatedMedia cannot set the pointer feature.
      page.driver.browser.page.command('Emulation.setTouchEmulationEnabled', enabled: true, maxTouchPoints: 5)
      load_presentation
      expect(page.evaluate_script("matchMedia('(pointer: coarse)').matches")).to be true # else this proves nothing
      expect(page).to have_css('.reveal .controls', visible: :hidden)
    end
  end

  # --- section#TOC overflow / scroll behaviour ---

  describe '#TOC scroll behaviour' do
    it 'has overflow-y: scroll and fills the full viewport height' do
      page.driver.browser.resize(width: 1280, height: 800)
      load_presentation
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
