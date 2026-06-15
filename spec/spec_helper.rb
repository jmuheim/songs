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
