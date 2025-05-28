# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'User Management API' do
  include IntegrationHelpers

  # --- Test User Setup ---
  let!(:admin_user) { create_admin_user }
  let!(:regular_user) { create_regular_user }
  let!(:test_role) { Fabricate(:role, role_name: 'TestRole') }

  def create_user_via_api(user_data)
    post '/admin/users', user_data
  end

  def update_user_via_api(id, user_data)
    put "/admin/users/#{id}", user_data
  end

  def delete_user_via_api(id)
    delete "/admin/users/#{id}"
  end

  before(:each) do
    # Bereinige die Benutzertabelle, aber behalte Admin und Regular User
    User.exclude(user_id: [admin_user.user_id, regular_user.user_id]).delete
    login_as(admin_user)
  end

  describe 'GET /admin/users' do
    it 'displays the user management page' do
      get '/admin/users'
      expect(response_status).to be(200)
      expect(response_body).to include('User Management')
    end

    it 'denies access for unauthenticated users' do
      logout
      get '/admin/users'
      expect(response_status).to be(302)
      expect(last_response.location).to include('/login')
    end

    it 'displays all existing users' do
      get '/admin/users'
      expect(response_status).to eq(200)
      expect(response_body).to include(admin_user.username)
      expect(response_body).to include(regular_user.username)
    end
  end

  describe 'POST /admin/users' do
    it 'creates a new user' do
      user_data = {
        username: 'newuser',
        email: 'newuser@example.com',
        first_name: 'New',
        last_name: 'User',
        password: DEFAULT_PASSWORD,
        'roles[]' => [test_role.role_id.to_s]
      }

      create_user_via_api(user_data)
      expect(response_status).to eq(201)

      user = User.first(username: 'newuser')
      expect(user).not_to be_nil
      expect(user.email).to eq('newuser@example.com')
      expect(user.first_name).to eq('New')
      expect(user.last_name).to eq('User')
      expect(user.roles.map(&:role_id)).to include(test_role.role_id)
    end

    it 'prevents creating users with duplicate usernames' do
      user_data = {
        username: 'uniqueuser',
        email: 'unique@example.com',
        first_name: 'Unique',
        last_name: 'User',
        password: DEFAULT_PASSWORD,
        'roles[]' => [test_role.role_id.to_s]
      }

      create_user_via_api(user_data)
      expect(response_status).to eq(201)

      create_user_via_api(user_data)
      expect(response_status).to eq(422)
    end
  end

  describe 'PUT /admin/users/:id' do
    let!(:test_user) do
      user = Fabricate(:user,
                       username: 'testuser',
                       email: 'test@example.com',
                       first_name: 'Test',
                       last_name: 'User',
                       is_active: true)
      Fabricate(:user_credential, user: user, password: DEFAULT_PASSWORD)
      user.add_role(test_role)
      user.refresh
      user
    end

    it 'updates an existing user' do
      update_data = {
        username: 'updateduser',
        email: 'updated@example.com',
        first_name: 'Updated',
        last_name: 'User',
        'roles[]' => [test_role.role_id.to_s]
      }

      update_user_via_api(test_user.user_id, update_data)
      expect(response_status).to eq(200)

      updated_user = User.first(user_id: test_user.user_id)
      expect(updated_user.username).to eq('updateduser')
      expect(updated_user.email).to eq('updated@example.com')
      expect(updated_user.first_name).to eq('Updated')
      expect(updated_user.last_name).to eq('User')
    end

    it 'updates password when provided' do
      update_data = {
        username: test_user.username,
        email: test_user.email,
        first_name: test_user.first_name,
        last_name: test_user.last_name,
        password: 'newpa$$worD123!',
        'roles[]' => [test_role.role_id.to_s]
      }

      update_user_via_api(test_user.user_id, update_data)
      expect(response_status).to eq(200)
    end

    it 'prevents updating to an already used username' do
      update_data = {
        username: regular_user.username,
        email: test_user.email,
        first_name: test_user.first_name,
        last_name: test_user.last_name,
        'roles[]' => [test_role.role_id.to_s]
      }

      update_user_via_api(test_user.user_id, update_data)
      expect(response_status).to eq(422)
    end

    it 'returns an error if the user does not exist' do
      update_data = {
        username: 'nonexistent',
        email: 'nonexistent@example.com',
        first_name: 'Non',
        last_name: 'Existent',
        'roles[]' => [test_role.role_id.to_s]
      }

      update_user_via_api(9999, update_data)
      expect(response_status).to eq(404)
    end

    it 'updates user roles' do
      new_role = Fabricate(:role, role_name: 'NewRole')

      update_data = {
        username: test_user.username,
        email: test_user.email,
        first_name: test_user.first_name,
        last_name: test_user.last_name,
        'roles[]' => [new_role.role_id.to_s]
      }

      update_user_via_api(test_user.user_id, update_data)
      expect(response_status).to eq(200)

      updated_user = User.first(user_id: test_user.user_id)
      expect(updated_user.roles.map(&:role_id)).not_to include(test_role.role_id)
      expect(updated_user.roles.map(&:role_id)).to include(new_role.role_id)
    end
  end

  describe 'DELETE /admin/users/:id' do
    let!(:user_to_delete) do
      user = Fabricate(:user,
                       username: 'deleteuser',
                       email: 'delete@example.com',
                       first_name: 'Delete',
                       last_name: 'User',
                       is_active: true)
      Fabricate(:user_credential, user: user, password: DEFAULT_PASSWORD)
      user.add_role(test_role)
      user.refresh
      user
    end

    it 'deletes an existing user' do
      delete_user_via_api(user_to_delete.user_id)
      expect(response_status).to eq(200)

      deleted_user = User.first(user_id: user_to_delete.user_id)
      expect(deleted_user).to be_nil
    end

    it 'returns an error if the user does not exist' do
      delete_user_via_api(9999)
      expect(response_status).to eq(404)
    end
  end

  describe 'Access control for non-admin users' do
    before(:each) do
      logout
      login_as(regular_user)
    end

    it 'denies regular users access to GET /admin/users' do
      get '/admin/users'
      expect(response_status).to eq(403)
    end

    it 'denies regular users to POST /admin/users' do
      user_data = {
        username: 'regularattempt',
        email: 'attempt@example.com',
        first_name: 'Regular',
        last_name: 'Attempt',
        password: DEFAULT_PASSWORD,
        'roles[]' => [test_role.role_id.to_s]
      }

      create_user_via_api(user_data)
      expect(response_status).to eq(403)
    end

    it 'denies regular users to PUT /admin/users/:id' do
      # Erst als Admin einen Benutzer erstellen
      logout
      login_as(admin_user)

      user_data = {
        username: 'adminuser',
        email: 'adminuser@example.com',
        first_name: 'Admin',
        last_name: 'Created',
        password: DEFAULT_PASSWORD,
        'roles[]' => [test_role.role_id.to_s]
      }

      create_user_via_api(user_data)
      expect(response_status).to eq(201)

      created_user = User.first(username: 'adminuser')
      expect(created_user).not_to be_nil

      # Dann als regulärer Benutzer versuchen, diesen zu aktualisieren
      logout
      login_as(regular_user)

      update_data = {
        username: 'hacked',
        email: 'hacked@example.com',
        first_name: 'Hacked',
        last_name: 'User',
        'roles[]' => [test_role.role_id.to_s]
      }

      update_user_via_api(created_user.user_id, update_data)
      expect(response_status).to eq(403)
    end

    it 'denies regular users to DELETE /admin/users/:id' do
      # Erst als Admin einen Benutzer erstellen
      logout
      login_as(admin_user)

      user_data = {
        username: 'deletetest',
        email: 'deletetest@example.com',
        first_name: 'Delete',
        last_name: 'Test',
        password: DEFAULT_PASSWORD,
        'roles[]' => [test_role.role_id.to_s]
      }

      create_user_via_api(user_data)
      expect(response_status).to eq(201)

      created_user = User.first(username: 'deletetest')
      expect(created_user).not_to be_nil

      # Dann als regulärer Benutzer versuchen, diesen zu löschen
      logout
      login_as(regular_user)

      delete_user_via_api(created_user.user_id)
      expect(response_status).to eq(403)
    end
  end
end
