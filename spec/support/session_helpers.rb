# Opening, joining and leaving a multiplex session, as the browser specs do
# it: shared by every spec that puts a tab into a session (index_html_spec.rb
# for live scrolling, song_wishes_spec.rb for the ❤️), so there is one way to
# log in as host and one to join. Included for type: :feature in spec_helper.rb.
module SessionHelpers
  # 🚀, 🔗 and the host login sit in the live-scroll dialog behind 🔥 (bottom left)
  def open_live_scroll_dialog
    # A toast that just appeared lifts the bottom corners clear of it over
    # 0.3s (night.css), and a click computed at the start of that slide lands
    # where 🔥 used to be
    wait_for_js("document.getElementById('bottom-left-controls').getAnimations().length === 0")
    find('#multiplex-status-button').click
    expect(page).to have_visible('#multiplex-info-modal')
  end

  # The session this device is in: its secret, in its storage
  def session_secret
    page.evaluate_script("(JSON.parse(localStorage.getItem('multiplex-session')) || {}).secret || null")
  end

  # Joins a session by the address of the host's QR code, as scanning it does
  def join_session(secret)
    visit "#{FixtureBuilder::URL_PATH}?live=#{secret}"
    wait_for_reveal
  end

  # Logs in as host from the 🔥 dialog: opens a session, or takes over the one
  # this tab is in. `label` is what the login button reads. The heartbeat is
  # shortened first, so whoever joins late and the end of a live scroll
  # arrive quickly, and so is the wishes' round (`wish_sync`), so a wish said
  # again, and one let go, are seen quickly too. The password is asked only
  # the first time on a device. Right after, the „Lieder von" dialog asks
  # whose songs the evening has (`only`: the Gastgeber to leave ticked, all by
  # default); it is confirmed here. A new session then shows its QR code; it
  # is closed again here.
  def log_in_as_host(heartbeat: 200, wish_sync: 300, label: 'Als Gastgeber anmelden', only: nil)
    page.execute_script("window.MULTIPLEX.heartbeat = #{heartbeat}; window.MULTIPLEX.wishSync = #{wish_sync}")
    open_live_scroll_dialog
    within('#multiplex-info-modal') { click_button("🔑 #{label}") }
    if page.has_css?('#host-modal[open]', wait: 0.5)
      within('#host-modal') do
        find('#host-pw').set(page.evaluate_script("window.MULTIPLEX.password"))
        click_button('Weiter')
      end
    end
    expect(page).to have_css('#host-login[hidden]', visible: :all)
    expect(page).to have_visible('#gastgeber-modal')
    within('#gastgeber-modal') do
      if only
        all('input[type=checkbox]').each { |box| box.set(only.include?(box.value)) }
      end
      click_button('OK')
    end
    if label == 'Als Gastgeber anmelden'
      within('#qr-modal') { click_button('Schliessen') }
    else
      expect(page).not_to have_visible('#qr-modal') # taken over: the guests are in already
    end
  end
end
