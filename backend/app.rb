require 'sinatra'
require 'sequel'

DB = Sequel.connect(
  adapter: 'postgres',
  host: ENV['DATABASE_HOST'] || 'db',
  database: ENV['DATABASE_NAME'] || 'licentra_development',
  user: ENV['DATABASE_USER'] || 'myusername',
  password: ENV['DATABASE_PASSWORD'] || 'mypassword'
)

get '/' do
    "Hello World! Connected to database: #{DB.opts[:database]}"
end

