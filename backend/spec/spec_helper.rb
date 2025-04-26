# frozen_string_literal: true

require 'logger'
require 'sequel'
require 'rspec'
require 'rack/test'
require 'fabrication'
require 'database_cleaner/sequel'

ENV['RACK_ENV'] = 'test'

require_relative 'support/test_database'

require_relative 'support/require_application'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.default_formatter = 'doc' if config.files_to_run.one?

  require_relative 'support/database_cleaner_config'
end

def session
  last_request.env['rack.session']
end
