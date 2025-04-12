require 'sinatra'
require 'sequel'
require_relative 'config/environment.rb'

# --- Routes ---

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

