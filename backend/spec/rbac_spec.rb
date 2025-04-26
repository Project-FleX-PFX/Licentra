# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../app'

RSpec.describe 'Authentication, Authorization, and Session Handling' do
  include Rack::Test::Methods

  def session
    last_request.env['rack.session']
  end

  def app
    Sinatra::Application
  end

  # --- Test Data Setup using Fabricators ---

  let!(:admin_role) { Fabricate(:role, role_name: 'Admin') }
  let!(:user_role)  { Fabricate(:role, role_name: 'User') }

  let!(:admin_user) do
    user = Fabricate(:user,
                     username: 'admin_test',
                     email: 'admin_test@example.com',
                     first_name: 'Admin',
                     last_name: 'Test',
                     is_active: true)
    Fabricate(:user_credential, user: user, password: 'password123')
    user.add_role(admin_role)
    user.add_role(user_role)
    user.refresh
    user
  end

  let!(:regular_user) do
    user = Fabricate(:user,
                     username: 'user_test',
                     email: 'user_test@example.com',
                     first_name: 'User',
                     last_name: 'Test',
                     is_active: true)
    Fabricate(:user_credential, user: user, password: 'password123')
    user.add_role(user_role)
    user.refresh
    user
  end

  # --- Helper for login in tests ---
  def login_as(email, password)
    post '/login', { email: email, password: password }
    follow_redirect! while last_response.redirect? # Follows any redirects after login
  end

  # --- Test Sections ---

  describe 'Login and Session Management' do
    it 'sets a session after successful login' do
      login_as(regular_user.email, 'password123')
      expect(session[:user_id]).to eq(regular_user.user_id)
    end

    it 'does not set a session with incorrect password and re-renders login page' do
      post '/login', { email: regular_user.email, password: 'wrongpassword' }
      expect(last_response).to be_ok
      expect(session[:user_id]).to be_nil
    end

    it 'clears session on logout' do
      login_as(regular_user.email, 'password123')
      get '/logout'
      expect(last_response).to be_redirect
      follow_redirect!
      expect(session[:user_id]).to be_nil
    end
  end

  describe 'Access Control (Authorization)' do
    context 'when user is an Admin' do
      before(:each) { login_as(admin_user.email, 'password123') }

      it 'can access admin-specific pages' do
        get '/user_management'
        expect(last_response).to be_ok

        get '/product_management'
        expect(last_response).to be_ok

        get '/license_management'
        expect(last_response).to be_ok

        get '/data'
        expect(last_response).to be_ok
      end

      it 'can also access regular user pages' do
        get '/profile'
        expect(last_response).to be_ok

        get '/my_license'
        expect(last_response).to be_ok
      end
    end

    context 'when user is a Regular User' do
      before(:each) { login_as(regular_user.email, 'password123') }

      it 'can access regular user pages' do
        get '/profile'
        expect(last_response).to be_ok

        get '/my_license'
        expect(last_response).to be_ok
      end

      it 'cannot access admin-specific pages' do
        get '/user_management'
        expect(last_response.status).to eq(403)
      end
    end

    context 'when user is not logged in (no session)' do
      it 'redirects to login page when accessing protected user pages' do
        get '/profile'
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end

      it 'redirects to login page when accessing protected admin pages' do
        get '/user_management'
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end
    end
  end
end
