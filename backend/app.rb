require 'sinatra'
require 'sequel'
require_relative 'config/environment.rb'

# --- load models ---
Dir[File.join(File.dirname(__FILE__), 'models', '*.rb')].each { |file| require file }

# --- Routes ---

get '/' do
    "Hello World! Connected to database: #{DB.opts[:database]}"
end

get '/data' do
  @products = Product.order(:product_id).all
  @license_types = LicenseType.order(:license_type_id).all
  @users = User.order(:user_id).all
  @licenses = License.eager(:product, :license_type).order(:license_id).all
  @assignments = LicenseAssignment.eager(:user, :license, :license_uses).order(:assignment_id).all
  @uses = LicenseUse.order(:use_id).all

  erb :data
end
