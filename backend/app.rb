require 'sinatra'
require 'sequel'
require_relative 'config/environment.rb'

# --- Routes ---
set :views, File.join(File.dirname(__FILE__), 'frontend', 'views')

DB = Sequel.connect(
  adapter: 'postgres',
  host: ENV['DATABASE_HOST'] || 'db',
  database: ENV['DATABASE_NAME'] || 'licentra_development',
  user: ENV['DATABASE_USER'] || 'myusername',
  password: ENV['DATABASE_PASSWORD'] || 'mypassword'
)

# Damit Sinatra weiß, wo sich der public-Ordner (für CSS, JS, Bilder) befindet:
set :public_folder, File.expand_path('../frontend/public', __dir__)

get '/' do
  "Hello World! Connected to database: #{DB.opts[:database]}"
end

get '/data' do
  @products = Product.order(:product_name).all
  @license_types = LicenseType.order(:type_name).all
  @roles = Role.order(:role_name).all
  @users = User.eager(:roles, :credential).order(:username).all
  @devices = Device.order(:device_name).all
  @licenses = License.eager(:product, :license_type).order(:license_name).all
  @assignments = LicenseAssignment.eager(:license, :user, :device).order(:assignment_id).all
  @logs = AssignmentLog.eager(:license_assignment).order(Sequel.desc(:log_timestamp)).all

  erb :data
end

get '/test' do
  erb :test
end

get '/userLicense' do
  erb :userLicense
end

get '/license' do
  @title = "License"
  @css   = "license"
  erb :license
end

get '/profile' do
  @title = "Profile"
  @css   = "profile"
  erb :profile
end

get '/my_license' do
  @title = "My License"
  @css   = "my_license"
  erb :my_license
end