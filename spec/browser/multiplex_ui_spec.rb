require 'capybara/rspec'

# Tests the master-mode modal and QR modal UI defined in style/body-controls.html.
# These handlers are registered only when window.io (socket.io) is available —
# the socket.io script loads from the live multiplex server, which must be reachable.
# If the external server is down, tests that open modals will be skipped.

RSpec.describe 'multiplex UI', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit '/index.html'
    sleep 1.5
  end

  def io_available?
    page.evaluate_script("typeof window.io === 'function'")
  end

  def modal_visible?(id)
    page.evaluate_script("document.getElementById('#{id}').classList.contains('visible')")
  end

  # --- Master modal ---

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
      find('#master-mode').click
      sleep 0.2
      expect(modal_visible?('master-modal')).to be true
    end

    it 'closes the master modal when Cancel is clicked' do
      find('#master-mode').click
      sleep 0.2
      find('#master-cancel').click
      sleep 0.2
      expect(modal_visible?('master-modal')).to be false
    end

    it 'clears the password input on cancel' do
      find('#master-mode').click
      sleep 0.2
      find('#master-pw').set('something')
      find('#master-cancel').click
      sleep 0.2
      expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
    end

    it 'adds the shake class briefly on wrong password' do
      find('#master-mode').click
      sleep 0.2
      find('#master-pw').set('wrongpassword')
      find('#master-confirm').click
      sleep 0.1
      # shake class is added immediately on wrong password
      shaking = page.evaluate_script("document.getElementById('master-pw').classList.contains('shake')")
      expect(shaking).to be true
    end

    it 'clears the input on wrong password' do
      find('#master-mode').click
      sleep 0.2
      find('#master-pw').set('wrongpassword')
      find('#master-confirm').click
      sleep 0.6  # shake animation is 0.4s, then class removed
      expect(page.evaluate_script("document.getElementById('master-pw').value")).to be_empty
    end

    it 'keeps the modal open after wrong password' do
      find('#master-mode').click
      sleep 0.2
      find('#master-pw').set('wrongpassword')
      find('#master-confirm').click
      sleep 0.2
      expect(modal_visible?('master-modal')).to be true
    end

    it 'grants master mode and closes modal on correct password' do
      password = page.evaluate_script("window.MULTIPLEX.password")
      find('#master-mode').click
      sleep 0.2
      find('#master-pw').set(password)
      find('#master-confirm').click
      sleep 0.3
      expect(modal_visible?('master-modal')).to be false
      expect(page.evaluate_script("document.getElementById('master-mode').classList.contains('is-master')")).to be true
    end

    it 'closes the master modal when clicking outside it' do
      find('#master-mode').click
      sleep 0.2
      # Click the overlay background (the modal container itself, not the box)
      page.execute_script("document.getElementById('master-modal').click()")
      sleep 0.2
      expect(modal_visible?('master-modal')).to be false
    end

    it 'opens the QR modal on #show-qr click' do
      find('#show-qr').click
      sleep 0.3
      expect(modal_visible?('qr-modal')).to be true
    end

    it 'closes the QR modal on close button click' do
      find('#show-qr').click
      sleep 0.3
      find('#qr-close').click
      sleep 0.2
      expect(modal_visible?('qr-modal')).to be false
    end

    it 'closes the QR modal when clicking outside it' do
      find('#show-qr').click
      sleep 0.3
      page.execute_script("document.getElementById('qr-modal').click()")
      sleep 0.2
      expect(modal_visible?('qr-modal')).to be false
    end
  end
end
