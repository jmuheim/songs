require 'capybara/rspec'

# The ❤️ on each song (wish_button in lib/build_helpers.rb, wired by
# style/wishes.js, carried over multiplex by style/body-controls.html): in a
# session, a device's wish to sing the song, counted across the room. One
# button in the song's TOC row and one on its title slide, under the same slug.
# Outside a session there is no room to count, so the hearts are hidden. See
# decisions/2026-11-11-guests-wish-for-songs-with-a-heart-counted-per-session.md.
RSpec.describe 'Song wishes (❤️)', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    MultiplexServer.start
    Capybara.app_host = FileServer.url
  end

  after { Capybara.reset_sessions! }

  IMAGINE  = 'imagine-john-lennon'.freeze
  CONNELLS = 'the-connells'.freeze
  RIPTIDE  = 'riptide---vance-joy'.freeze

  def toc_heart(slug)   = %(#TOC ol li button.song-wish[data-song="#{slug}"])
  def title_heart(slug) = %(section##{slug} button.song-wish[data-song="#{slug}"])

  # A heart in the given state: pressed (this device wishes the song) or not,
  # with `count` devices wishing it (nil: the count is empty, i.e. none)
  def expect_heart(selector, pressed:, count:, visible: true)
    expect(page).to have_css("#{selector}[aria-pressed=\"#{pressed}\"]", visible: visible)
    if count
      expect(page).to have_css("#{selector} .song-wish-count", text: count.to_s, exact_text: true, visible: visible)
    else
      expect(page).to have_css("#{selector} .song-wish-count:empty", visible: :all)
    end
  end

  def go_to_toc
    click_link 'Inhaltsverzeichnis' # the 📖 control
    expect(page).to have_css('#TOC.present')
  end

  def end_session
    open_live_scroll_dialog
    within('#multiplex-info-modal') { click_button('🏁 Runde beenden') }
    expect(page).to have_no_css('body.wishes-active')
  end

  it 'shows the hearts in a session only; a wish is made from the TOC row or the title slide alike, outlasts a reload, and goes with the session' do
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
    go_to_toc
    # Outside a session: in the markup, but with no room to count, hidden
    expect(page).to have_css(toc_heart(IMAGINE), visible: :hidden)
    expect(page).to have_no_css('body.wishes-active')

    log_in_as_host
    expect(page).to have_css('body.wishes-active')
    expect_heart(toc_heart(IMAGINE), pressed: false, count: nil)
    expect(page).to have_css("#{toc_heart(IMAGINE)} .visually-hidden", text: 'Lied wünschen, 0 Wünsche', visible: :all)

    find(toc_heart(IMAGINE)).click
    expect_heart(toc_heart(IMAGINE), pressed: true, count: 1)
    expect(page).to have_css("#{toc_heart(IMAGINE)} .visually-hidden", text: 'Lied wünschen, 1 Wunsch', visible: :all)
    expect(page).to have_css('#TOC.present') # a wish does not navigate
    expect_heart(toc_heart(CONNELLS), pressed: false, count: nil) # only that song

    # In the TOC the hearts stand in one column at the row's right edge, with
    # a count beside them (Imagine) or without, and the title runs on under
    # the heart, fading out into the list's own background instead of ending
    # in "…". Outside a session the row's own overlay fades it
    # (toc_filter_spec.rb); here it is off, or it would cover the heart.
    heart_rights, list_right, overflow, fade, fade_origin, list_background, row_overlay = page.evaluate_script(<<~JS)
      [Array.from(document.querySelectorAll('#TOC ol li .song-wish-heart')).map(function (heart) {
         return Math.round(heart.getBoundingClientRect().right);
       }),
       Math.round(document.querySelector('#TOC ol').getBoundingClientRect().right),
       getComputedStyle(document.querySelector('#TOC ol li a')).textOverflow,
       getComputedStyle(document.querySelector('#TOC ol li button.song-wish')).backgroundImage,
       getComputedStyle(document.querySelector('#TOC ol li button.song-wish')).backgroundOrigin,
       getComputedStyle(document.body).backgroundColor,
       getComputedStyle(document.querySelector('#TOC ol li'), '::after').display]
    JS
    expect(heart_rights.uniq.size).to eq(1)
    # …ending at the list's edge, as the titles start at it, no wider a gap
    expect(heart_rights.first).to be_within(1).of(list_right)
    expect(overflow).to eq('clip')
    expect(fade).to start_with('linear-gradient').and include(list_background)
    expect(row_overlay).to eq('none')
    # From the border's outer edge: from the padding's, the gradient repeated
    # its transparent start under the 2px border, and a long title peeked out
    # beside the heart (on a phone)
    expect(fade_origin).to eq('border-box')

    # The song's title slide carries the same wish
    click_link 'Imagine (John Lennon)'
    expect(page).to have_css("section##{IMAGINE}.present")
    expect_heart(title_heart(IMAGINE), pressed: true, count: 1)

    # A reload keeps it: the wishes live with the session. Reveal writes the
    # address within a second; the reload must come back to this slide.
    wait_for_js("location.hash === '#/#{IMAGINE}'")
    page.refresh
    wait_for_reveal
    expect(page).to have_css("section##{IMAGINE}.present")
    expect_heart(title_heart(IMAGINE), pressed: true, count: 1)

    # Taken back from the title slide, it is gone in the TOC too
    find(title_heart(IMAGINE)).click
    expect_heart(title_heart(IMAGINE), pressed: false, count: nil)
    expect_heart(toc_heart(IMAGINE), pressed: false, count: nil, visible: :all) # the TOC is not the present slide

    # Wished again, then the session ends: the hearts go, and the wish with them
    find(title_heart(IMAGINE)).click
    expect_heart(title_heart(IMAGINE), pressed: true, count: 1)
    end_session
    expect(page).to have_css(title_heart(IMAGINE), visible: :hidden)
    expect(page.evaluate_script("localStorage.getItem('multiplex-session')")).to be_nil

    # The next evening starts from none
    log_in_as_host
    expect_heart(title_heart(IMAGINE), pressed: false, count: nil)
  end

  it 'counts the room: every device sees how many wish a song as wishes come and go, a reload included, and a device that fell silent drops out' do
    secret = nil
    using_session(:host) do
      visit FixtureBuilder::URL_PATH
      wait_for_reveal
      go_to_toc
      log_in_as_host
      secret = session_secret
      find(toc_heart(IMAGINE)).click
      expect_heart(toc_heart(IMAGINE), pressed: true, count: 1)
    end

    using_session(:guest) do
      join_session(secret)
      # Shortened like the host's (log_in_as_host): a device unheard for three
      # rounds is let go, and the host says its wishes again every round
      page.execute_script('window.MULTIPLEX.wishSync = 300')
      go_to_toc
      expect(page).to have_css('body.wishes-active')
      # The host's wish is counted here within a round, but is not this device's
      expect_heart(toc_heart(IMAGINE), pressed: false, count: 1)

      find(toc_heart(IMAGINE)).click
      expect_heart(toc_heart(IMAGINE), pressed: true, count: 2)
      find(toc_heart(CONNELLS)).click
      expect_heart(toc_heart(CONNELLS), pressed: true, count: 1)
    end

    using_session(:host) do
      expect_heart(toc_heart(IMAGINE), pressed: true, count: 2)
      expect_heart(toc_heart(CONNELLS), pressed: false, count: 1)
    end

    using_session(:guest) do
      find(toc_heart(IMAGINE)).click # taken back
      expect_heart(toc_heart(IMAGINE), pressed: false, count: 1)
      # A reload: this device's wishes come back, and are said again
      page.refresh
      wait_for_reveal
      go_to_toc
      expect_heart(toc_heart(CONNELLS), pressed: true, count: 1)
      expect_heart(toc_heart(IMAGINE), pressed: false, count: 1)
    end

    using_session(:host) do
      expect_heart(toc_heart(IMAGINE), pressed: true, count: 1)
      expect_heart(toc_heart(CONNELLS), pressed: false, count: 1)

      # A device that falls silent: a second socket (forceNew, so the relay
      # sees another client) says a wish once and never again, as a guest
      # whose tab was closed would. It is counted, and let go three rounds
      # later. A real tab can't do this: it says its wishes again every round.
      page.execute_script(<<~JS)
        window._spy = io(window.MULTIPLEX.url, { forceNew: true });
        window._spy.on('connect', function() {
          window._spy.emit('multiplex-statechanged', {
            type: 'wish', wishes: ['#{RIPTIDE}'], from: 'spy',
            secret: window.MULTIPLEX.secret, socketId: window.MULTIPLEX.socketId
          });
        });
      JS
      expect_heart(toc_heart(RIPTIDE), pressed: false, count: 1)
      expect_heart(toc_heart(RIPTIDE), pressed: false, count: nil)

      # The host ends the session: the hearts go everywhere, and the wishes with them
      end_session
    end

    using_session(:guest) do
      expect(page).to have_no_css('body.wishes-active')
      expect(page).to have_css(toc_heart(CONNELLS), visible: :hidden)
      expect(page.evaluate_script("localStorage.getItem('multiplex-session')")).to be_nil
    end
  end
end
