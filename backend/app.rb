# frozen_string_literal: true

# frozen_string_literal: true

require 'sinatra'
require 'sequel'
require_relative 'config/environment'
require_relative 'dao/user_dao'
require_relative 'dao/role_dao'

# Enable sessions
enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
set :host_authorization, { permitted_hosts: ['vmd166389.contaboserver.net', 'localhost', '127.0.0.1'] }

# --- Helper Methods ---
helpers do
  def current_user
    @current_user ||= session[:user_id] ? UserDAO.find(session[:user_id]) : nil
  end

  def logged_in?
    !current_user.nil?
  end

  def has_role?(role_name)
    return false unless logged_in?

    current_user.roles.any? { |role| role.role_name == role_name }
  end

  def require_login
    unless logged_in?
      session[:return_to] = request.path_info
      redirect '/login'
    end
  end

  def require_role(role_name)
    require_login

    unless has_role?(role_name)
      halt 403, erb(:forbidden, layout: true, locals: { message: "You don't have permission to access this page." })
    end
  end
end

# --- Routes ---
set :views, File.join(File.dirname(__FILE__), 'frontend', 'views')

# Hard coded as docker sets up directory structure
set :public_folder, '/app/frontend/public'

# Globale Testvariable
isAdmin = true  # Zum Testen hier einfach auf true oder false setzen für admin/user view

helpers do
  def admin?
    settings.isAdmin
  end
end

before do
  settings.set :isAdmin, isAdmin
end

# --- Routes ---
get '/' do
  redirect logged_in? ? '/profile' : '/login'
end

get '/login' do
  redirect '/profile' if logged_in?
  erb :login, layout: false
end

post '/login' do
  email = params[:email]
  password = params[:password]

  if email.nil? || email.empty? || password.nil? || password.empty?
    @error = "Bitte E‑Mail und Passwort ausfüllen."
    return erb :login, layout: false
  end

  begin
    user = UserDAO.find_by_email(email)

    if user && user.is_active && user.authenticate(password)
      session[:user_id] = user.user_id

      # Redirect to the original requested URL or default to profile
      redirect_url = session[:return_to] || '/profile'
      session.delete(:return_to)
      redirect redirect_url
    else
      @error = "Ungültige E-Mail oder Passwort."
      erb :login, layout: false
    end
  rescue => e
    @error = "Ein Fehler ist aufgetreten: #{e.message}"
    erb :login, layout: false
  end
end

get '/logout' do
  session.clear
  redirect '/login'
end

get '/data' do
  require_role('Admin')
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

get '/license' do
  require_login
  @title = 'License'
  @css   = 'license'
  erb :license
end

get '/profile' do
  require_login
  @title = 'Profile'
  @css   = 'profile'
  @user = current_user
  erb :profile
end

get '/my_license' do
  require_login
  @title = 'My License'
  @css   = 'my_license'
  erb :my_license
end

get '/register' do
  erb :register, layout: false
end

get '/user_management' do
  erb :user_management
end

get '/product_management' do
  erb :product_management
end

get '/license_management' do
  erb :license_management
end

get '/forbidden' do
  erb :forbidden, layout: true
end
