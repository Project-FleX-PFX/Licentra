# frozen_string_literal: true

require 'sinatra'
require 'sequel'
require_relative 'config/environment'
require_relative 'dao/user_dao'
require_relative 'dao/role_dao'

# Enable sessions
enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

configure :production, :development do
  set :host_authorization, { permitted_hosts: ['licensemanager.licentra.de', 'localhost', '127.0.0.1'] }
end

configure :test do
  set :host_authorization, { permitted_hosts: ['licensemanager.licentra.de', 'localhost', '127.0.0.1', 'example.org'] }
end

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

  def admin?
    has_role?('Admin')
  end

  def require_login
    return if logged_in?

    session[:return_to] = request.path_info
    redirect '/login'
  end

  def require_role(role_name)
    require_login

    return if has_role?(role_name)

    halt 403, erb(:forbidden, layout: true, locals: { message: "You don't have permission to access this page." })
  end
end

# --- Routes ---
set :views, File.join(File.dirname(__FILE__), 'frontend', 'views')

# Hard coded as docker sets up directory structure
set :public_folder, '/app/frontend/public'

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
    @error = 'Bitte E‑Mail und Passwort ausfüllen.'
    return erb :login, layout: false
  end

  begin
    user = UserDAO.find_by_email(email)

    if user&.is_active && user.authenticate(password)
      session[:user_id] = user.user_id

      # Redirect to the original requested URL or default to profile
      redirect_url = session[:return_to] || '/profile'
      session.delete(:return_to)
      redirect redirect_url
    else
      @error = 'Ungültige E-Mail oder Passwort.'
      erb :login, layout: false
    end
  rescue StandardError => e
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
  @products = ProductDAO.all
  @license_types = LicenseTypeDAO.all
  @roles = RoleDAO.all
  @users = UserDAO.all
  @devices = DeviceDAO.all
  @licenses = LicenseDAO.all
  @assignments = LicenseAssignmentDAO.all
  @logs = AssignmentLogDAO.all

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

post '/update_profile' do
  require_login
  content_type :json

  field = params[:field]
  value = params[:value]

  allowed_fields = %w[username email password]
  return { success: false, message: 'Invalid field' }.to_json unless allowed_fields.include?(field)

  begin
    user = current_user

    case field
    when 'username'
      # Check whether the username already exists
      existing_user = UserDAO.find_by_username(value)
      if existing_user && existing_user.user_id != user.user_id
        return { success: false, message: 'Username already exists' }.to_json
      end

      UserDAO.update(user.user_id, username: value)
    when 'email'
      # Check whether the email already exists
      existing_user = UserDAO.find_by_email(value)
      if existing_user && existing_user.user_id != user.user_id
        return { success: false, message: 'Email already exists' }.to_json
      end

      UserDAO.update(user.user_id, email: value)
    when 'password'
      # Update password
      UserCredentialDAO.update_password(user.user_id, value)
    end

    { success: true }.to_json
  rescue StandardError => e
    { success: false, message: e.message }.to_json
  end
end

get '/register' do
  erb :register, layout: false
end

post '/register' do
  # Validation of the entries
  username = params[:username]
  first_name = params[:first_name]
  last_name = params[:last_name]
  email = params[:email]
  password = params[:password]
  password_confirmation = params[:password_confirmation]

  # Check that all fields are filled in
  if [username, first_name, last_name, email, password, password_confirmation].any?(&:empty?)
    @error = 'Bitte füllen Sie alle Felder aus.'
    return erb :register, layout: false
  end

  # Check whether the passwords match
  if password != password_confirmation
    @error = 'Die Passwörter stimmen nicht überein.'
    return erb :register, layout: false
  end

  # Check whether the user name already exists
  if UserDAO.find_by_username(username)
    @error = 'Der Benutzername ist bereits vergeben.'
    return erb :register, layout: false
  end

  # Check whether the e-mail already exists
  if UserDAO.find_by_email(email)
    @error = 'Die E-Mail-Adresse ist bereits registriert.'
    return erb :register, layout: false
  end

  is_first_user = UserDAO.all.empty?

  begin
    # Create user
    user = User.new(
      username: username,
      email: email,
      first_name: first_name,
      last_name: last_name,
      is_active: true,
      credential_attributes: { password_plain: password }
    )

    user.save

    if is_first_user
      admin_role = RoleDAO.find_by_name('Admin')
      user.add_role(admin_role) if admin_role
      # Log entry for security audit
      puts "First user #{username} registered and assigned Admin role"
    end

    # Assign standard role "User
    user_role = RoleDAO.find_by_name('User')
    user.add_role(user_role) if user_role

    # Save user in the session and log in
    session[:user_id] = user.user_id

    # Forwarding to the profile
    redirect '/profile'
  rescue StandardError => e
    @error = "Fehler bei der Registrierung: #{e.message}"
    erb :register, layout: false
  end
end

get '/user_management' do
  require_role('Admin')
  erb :user_management
end

get '/product_management' do
  require_role('Admin')
  erb :product_management
end

get '/license_management' do
  require_role('Admin')
  erb :license_management
end

get '/forbidden' do
  erb :forbidden, layout: true
end
