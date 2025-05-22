# frozen_string_literal: true

require 'sinatra'
require 'sequel'
require 'sinatra/base'
require 'rack/flash'
require_relative 'config/environment'

# Load all files in order
Dir.glob('./dao/*.rb').sort.each { |file| require file }
Dir.glob('./helpers/*.rb').sort.each { |file| require file }
Dir.glob('./services/*.rb').sort.each { |file| require file }
Dir.glob('./routes/*.rb').sort.each { |file| require file }

class LicentraApp < Sinatra::Base
  enable :method_override
  enable :sessions
  set :erb, escape_html: true
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  set :root, '/app'
  set :views, '/app/frontend/views'
  set :public_folder, '/app/frontend/public'
  set :layout, '/app/frontend/views/layouts/application'

  use Rack::Flash, sweep: true

  configure :production, :development do
    set :host_authorization, { permitted_hosts: ['licensemanager.licentra.de', 'localhost', '127.0.0.1'] }
    disable :show_exceptions
    disable :raise_errors
  end

  configure :test do
    set :host_authorization,
        { permitted_hosts: ['licensemanager.licentra.de', 'localhost', '127.0.0.1', 'example.org'] }
  end

  helpers AuthHelpers
  helpers ApplicationHelpers

  get '/' do
    redirect logged_in? ? '/profile' : '/login'
  end

  get '/forbidden' do
    erb :'errors/403', layout: true
  end

  register AuthRoutes
  register ProfileRoutes
  register LicenseRoutes
  register AdminRoutes
  register HistoryRoutes
  register ErrorHandlers
end

run LicentraApp if __FILE__ == $PROGRAM_NAME
