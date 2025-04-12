require 'sequel'
require 'logger'

db_host = ENV.fetch('POSTGRES_HOST', 'db')
db_name = ENV.fetch('POSTGRES_DB', 'licentra_development')
db_user = ENV.fetch('POSTGRES_USER', 'myusername')
db_pass = ENV.fetch('POSTGRES_PASSWORD', 'mypassword')
db_port = ENV.fetch('POSTGRES_PORT', 5432)

DATABASE_URL = "postgres://#{db_user}:#{db_pass}@#{db_host}:#{db_port}/#{db_name}"

DB = Sequel.connect(DATABASE_URL)

DB.loggers << Logger.new($stdout)

Sequel.extension :migration
DB.extension :pg_array
DB.extension :pagination
