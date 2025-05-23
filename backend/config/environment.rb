# frozen_string_literal: true

require 'sequel'
require 'logger'

unless ENV['RACK_ENV'] == 'test'
  db_host = ENV.fetch('DATABASE_HOST', 'db')
  db_name = ENV.fetch('DATABASE_NAME', 'licentra_development')
  db_user = ENV.fetch('DATABASE_USER', 'myusername')
  db_pass = ENV.fetch('DATABASE_PASSWORD', 'mypassword')
  db_port = ENV.fetch('DATABASE_PORT', 5432)

  DATABASE_URL = "postgres://#{db_user}:#{db_pass}@#{db_host}:#{db_port}/#{db_name}"

  DB = Sequel.connect(DATABASE_URL)

  DB.loggers << Logger.new($stdout)

  DB.extension :pg_array
  DB.extension :pagination

  Sequel.extension :migration
  Sequel::Model.plugin :validation_helpers
  Sequel::Model.plugin :association_proxies

  # --- load models and DAOs ---
  unless ENV['MIGRATION_ONLY'] == 'true'
    Dir[File.join(__dir__, '..', 'models', '*.rb')].sort.each { |file| require file }
    Dir[File.join(__dir__, '..', 'dao', '*.rb')].sort.each { |file| require file }
  end

end
