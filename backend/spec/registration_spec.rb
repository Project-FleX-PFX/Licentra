# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../app'

RSpec.describe 'User Registration' do
  include Rack::Test::Methods

  def register_user(username, email, first_name: 'Test', last_name: 'User', password: DEFAULT_PASSWORD)
    post '/register', {
      username: username,
      email: email,
      first_name: first_name,
      last_name: last_name,
      password: password,
      password_confirmation: password
    }
  end

  def verify_user_roles(username, expected_roles)
    user = User.first(username: username)
    expect(user).not_to be_nil
    user_role_names = user.roles.map(&:role_name)
    expect(user_role_names).to match_array(expected_roles)
  end

  describe 'First User Admin Assignment' do
    before do
      Role.find_or_create(role_name: 'Admin')
      Role.find_or_create(role_name: 'User')
    end

    it 'assigns Admin and User roles to the first registered user' do
      register_user('firstuser', 'first@example.com', first_name: 'First', last_name: 'User')

      expect(last_response).to be_redirect
      verify_user_roles('firstuser', %w[Admin User])

      user = User.first(username: 'firstuser')
      expect(user.first_name).to eq('First')
      expect(user.last_name).to eq('User')
    end

    it 'assigns only User role to subsequent registered users' do
      register_user('firstadmin', 'admin@example.com', first_name: 'Admin', last_name: 'Person')
      expect(last_response).to be_redirect

      register_user('seconduser', 'second@example.com', first_name: 'Regular', last_name: 'Joe')
      expect(last_response).to be_redirect

      verify_user_roles('seconduser', ['User'])

      user = User.first(username: 'seconduser')
      expect(user.first_name).to eq('Regular')
      expect(user.last_name).to eq('Joe')
    end
  end

  describe 'Validation Errors' do
    before do
      Role.find_or_create(role_name: 'User')
      register_user('existinguser', 'existing@example.com')
      expect(last_response).to be_redirect
    end

    it 'rejects registration with duplicate username' do
      register_user('existinguser', 'new@example.com')

      expect(last_response).to be_ok
      expect(last_response.body).to include('already taken')
    end

    it 'rejects registration with duplicate email' do
      register_user('newuser', 'existing@example.com')

      expect(last_response).to be_ok
      expect(last_response.body).to include('already registered')
    end

    it 'rejects registration with mismatched passwords' do
      post '/register', {
        username: 'newuser',
        email: 'new@example.com',
        first_name: 'New',
        last_name: 'User',
        password: DEFAULT_PASSWORD,
        password_confirmation: 'differenT123!'
      }

      expect(last_response).to be_ok
      expect(last_response.body).to include('match')
    end
  end
end
