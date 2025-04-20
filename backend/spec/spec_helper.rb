require 'sequel'
require 'rspec'
require 'fabrication'
require 'database_cleaner/sequel'

ENV['RACK_ENV'] = 'test'

DB = Sequel.connect('sqlite:///:memory:')
puts "Running tests with database: #{DB.adapter_scheme} (In-Memory)"

Sequel.extension :migration
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :association_proxies

migration_path = File.expand_path('../db/migrations', __dir__)
unless File.directory?(migration_path)
  raise "Migrations directory not found at #{migration_path}"
end
puts "Running migrations from: #{migration_path}"
begin
  Sequel::Migrator.run(DB, migration_path)
  puts "Migrations applied successfully."
rescue StandardError => e
  puts "Error running migrations: #{e.message}"
  puts e.backtrace
  exit
end

require_relative '../dao/errors'
require_relative '../dao/logger'
require_relative '../dao/error_handling'
require_relative '../dao/base_dao'
require_relative '../dao/concerns/crud_operations'

Dir[File.expand_path('../models/**/*.rb', __dir__)].sort.each { |f| require f }

dao_files = Dir[File.expand_path('../dao/**/*.rb', __dir__)]
dao_files.sort_by! { |f| [f.include?('logging') || f.include?('error_handling') ? 0 : 1, f] }
dao_files.each { |f| require f unless f.end_with?('concerns/crud_operations.rb') || f.end_with?('base_dao.rb') }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end
  # config.profile_examples = 10 # Finde langsame Tests
  config.order = :random
  Kernel.srand config.seed

  # --- Database Cleaner Configuration ---
  config.before(:suite) do
    DatabaseCleaner[:sequel].strategy = :transaction
    DatabaseCleaner[:sequel].clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner[:sequel].cleaning do
      example.run
    end
  end
end
