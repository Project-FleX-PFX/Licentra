# frozen_string_literal: true

DB = Sequel.connect('sqlite:///:memory:')
puts "Running tests with database: #{DB.adapter_scheme} (In-Memory)"

Sequel.extension :migration
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :association_proxies

def find_and_validate_migration_path
  path = File.expand_path('../../db/migrations', __dir__)
  raise "Migrations directory not found at #{path}" unless File.directory?(path)

  path
end

def report_migration_error_and_exit(error)
  puts "Error running migrations: #{error.message}"
  puts error.backtrace
  exit # Crucial: Stop tests if migrations fail
end

def run_migrations
  migration_path = find_and_validate_migration_path
  puts "Running migrations from: #{migration_path}"
  begin
    Sequel::Migrator.run(DB, migration_path)
    puts 'Migrations applied successfully.'
  rescue StandardError => e
    report_migration_error_and_exit(e)
  end
end

run_migrations
