require 'capybara/rspec'

# The table of contents carries a Sprache/Genre filter (built by inject_toc_filter
# in lib/build_helpers.rb, wired by style/toc-filter.js). The fixture songs are
# tagged so that Deutsch = {74-75} and Englisch = {Across, I Have a Dream, Imagine}
# are disjoint, and likewise Rock = {74-75} and Pop = the other three — a clean
# test of single-select filtering within a category and AND across categories.
RSpec.describe 'TOC tag filter', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    MultiplexServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
    click_link 'Table of contents' # the 📖 control → #/1
    expect(page).to have_css('#TOC.present')
  end

  # Titles of the TOC entries the filter leaves showing, whitespace-normalised.
  def visible_entries
    all('#TOC nav li:not(.toc-hidden) a', visible: :all).map { |a| a.text.gsub(/\s+/, ' ').strip }
  end

  it 'offers a Sprache and a Genre dropdown, both unset, under a visually-hidden "Filter" legend' do
    aggregate_failures do
      within '#toc-filter' do
        expect(page).to have_css('legend.visually-hidden', text: 'Filter', visible: :all) # reaches a screen reader, not the screen
        expect(page).to have_select('Sprache', options: ['Alle', 'Deutsch', 'Englisch'])
        expect(page).to have_select('Genre', options: ['Alle', 'Pop', 'Rock'])
        expect(page).to have_select('Sprache', selected: 'Alle')
        expect(page).to have_select('Genre', selected: 'Alle')
        expect(page).to have_button('Reset')
      end
      expect(visible_entries).to include('74-75 (The Connells)') # nothing hidden yet
      # The Introduction isn't a song and carries no tags — the build drops it
      # from the TOC entirely rather than just excluding it from the filter.
      within '#TOC nav' do
        expect(page).to have_no_link('Introduction')
      end
      expect(page).to have_css('#TOC nav ol') # an ordered list, not a <ul>
      expect(page).to have_no_css('#TOC nav ul')
    end
  end

  it 'filters to the selected Sprache, and restores everything on "Alle", without paging the deck' do
    select 'Deutsch', from: 'Sprache'
    expect(visible_entries).to eq(['74-75 (The Connells)']) # Deutsch = {74-75}
    expect(page).to have_css('#TOC.present') # a select change must not navigate the deck

    select 'Alle', from: 'Sprache'
    expect(visible_entries).to include('Imagine (John Lennon)')
  end

  it 'combines Sprache and Genre with AND, and shows a "no results" message for an empty intersection' do
    select 'Englisch', from: 'Sprache'
    select 'Pop', from: 'Genre'
    # Englisch ∩ Pop = the three Pop songs; 74-75 is Deutsch/Rock, so it drops out.
    expect(visible_entries).to contain_exactly(
      'Across the universe (Beatles)',
      'I Have a Dream (ABBA)',
      'Imagine (John Lennon)'
    )
    expect(page).to have_no_css('#toc-filter-empty', visible: :visible)

    select 'Rock', from: 'Genre'
    # Englisch ∩ Rock is empty — 74-75 (the only Rock song) is Deutsch, not Englisch.
    expect(visible_entries).to be_empty
    expect(page).to have_css('#toc-filter-empty', text: 'Keine Ergebnisse, bitte Filter anpassen')

    select 'Pop', from: 'Genre'
    expect(page).to have_no_css('#toc-filter-empty', visible: :visible) # results again, message gone
  end

  it 'hides untagged entries while filtering and restores them with Reset' do
    select 'Pop', from: 'Genre'
    expect(visible_entries).not_to include('74-75 (The Connells)')  # Rock only, no Pop
    expect(visible_entries.size).to eq(3)

    click_button 'Reset'
    expect(visible_entries).to include('74-75 (The Connells)')
    expect(page).to have_select('Sprache', selected: 'Alle')
    expect(page).to have_select('Genre', selected: 'Alle')
  end

  it 'stays visible (sticky) even once the list has scrolled past a full screen' do
    expect(page.evaluate_script("getComputedStyle(document.getElementById('toc-filter')).position")).to eq('sticky')
    expect(page.evaluate_script("getComputedStyle(document.getElementById('toc-filter')).top")).to eq('0px')

    # The fixture book has only 5 entries, too short to overflow the window at
    # its default size — shrink it so the list overflows a single screen, the
    # condition that actually exercises stickiness. #TOC's present slide is
    # display:flex, and flex's default align-items:stretch used to cap
    # .slide-content at the viewport height; position:sticky only sticks
    # within its containing block, so past that cap the filter just scrolled
    # away with everything else instead of staying put (see night.css and the
    # decision log for the fix).
    begin
      page.driver.browser.resize(width: 1280, height: 100)
      page.evaluate_script("window.dispatchEvent(new Event('resize'))") # Cuprite's resize doesn't fire the browser event
      page.evaluate_script("document.getElementById('TOC').scrollTop = 999")
      expect(page.evaluate_script("document.getElementById('toc-filter').getBoundingClientRect().top")).to eq(0)
    ensure
      page.driver.browser.resize(width: 1280, height: 800)
    end
  end

  it 'keeps the TOC at a constant ~90% width and truncates an overflowing title with an ellipsis' do
    ol_width, nav_width = page.evaluate_script(<<~JS)
      [
        document.querySelector('#TOC nav ol').getBoundingClientRect().width,
        document.querySelector('#TOC nav').getBoundingClientRect().width
      ]
    JS
    expect(ol_width.to_f / nav_width).to be_within(0.01).of(0.9)

    link_style = page.evaluate_script(<<~JS)
      (function() {
        var a = document.querySelector('#TOC nav ol li a');
        var cs = getComputedStyle(a);
        return [cs.whiteSpace, cs.overflow, cs.textOverflow];
      })()
    JS
    expect(link_style).to eq(%w[nowrap hidden ellipsis])
  end
end
