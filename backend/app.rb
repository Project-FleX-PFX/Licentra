require 'sinatra'
require 'sequel'
require_relative 'config/environment.rb'

set :host_authorization, { permitted_hosts: ['vmd166389.contaboserver.net', 'localhost', '127.0.0.1'] }


# --- Routes ---
set :views, File.join(File.dirname(__FILE__), 'frontend', 'views')

# Hard coded as docker sets up directory structure
set :public_folder, '/app/frontend/public'

# --- Routes ---

get '/' do
  "Hello World! Connected to database: #{DB.opts[:database]}"
end

get '/data' do
  @products = Product.order(:product_name).all
  @license_types = LicenseType.order(:type_name).all
  @roles = Role.order(:role_name).all
  @users = User.eager(:roles, :credential).order(:username).all
  @devices = DeviceDAO.all
  @licenses = License.eager(:product, :license_type).order(:license_name).all
  @assignments = LicenseAssignment.eager(:license, :user, :device).order(:assignment_id).all
  @logs = AssignmentLog.eager(:license_assignment).order(Sequel.desc(:log_timestamp)).all

  erb :data, layout: false
end

get '/login' do
  erb :login, layout: false
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

get '/register' do
  erb :register, layout: false
end
