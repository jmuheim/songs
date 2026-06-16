require 'capybara/rspec'
require 'capybara/cuprite'
require_relative 'support/file_server'

PROJECT_ROOT = File.expand_path('..', __dir__)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    headless:    true,
    window_size: [1280, 800],
    browser_options: { 'no-sandbox': nil }
  )
end

Capybara.default_driver    = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 10
Capybara.run_server = false

module BrowserHelpers
  # Poll until Reveal.js is ready instead of a fixed sleep.
  # Typical init time is ~0.3 s; this avoids burning the remaining ~1.2 s.
  def wait_for_reveal(timeout: 5)
    deadline = Time.now + timeout
    sleep 0.05 until page.evaluate_script("!!(window.Reveal && Reveal.isReady())") ||
                     Time.now > deadline
    raise "Reveal.js did not initialize within #{timeout}s" \
      unless page.evaluate_script("!!(window.Reveal && Reveal.isReady())")
  end
end

RSpec.configure do |config|
  config.include BrowserHelpers, type: :feature
end
