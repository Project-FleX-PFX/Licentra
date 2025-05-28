# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'User Management API' do
  include IntegrationHelpers

  # --- Test User Setup ---
  let!(:admin_user) { create_admin_user }
  let!(:regular_user) { create_regular_user }
  let!(:test_role) { Fabricate(:role, role_name: 'TestRole') }

  def create_user_via_api(user_details, role_ids = [])
    payload = { user: user_details }
    payload[:user_role_ids] = role_ids unless role_ids.empty?
    post '/admin/users', payload
  end

  def update_user_via_api(id, user_details, role_ids = nil)
    payload = {}
    user_details_keys = %i[username email first_name last_name password new_password password_confirmation is_active]

    filtered_user_details = user_details.slice(*user_details_keys.map(&:to_s), *user_details_keys.map(&:to_sym))
    if filtered_user_details[:password] && !filtered_user_details[:new_password]
      filtered_user_details[:new_password] = filtered_user_details.delete(:password)
    end

    payload[:user] = filtered_user_details unless filtered_user_details.empty?

    payload[:user_role_ids] = role_ids if role_ids

    patch "/admin/users/#{id}", payload
  end

  def delete_user_via_api(id)
    delete "/admin/users/#{id}"
  end

  before(:each) do
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
      user_details = {
        username: 'newuser',
        email: 'newuser@example.com',
        first_name: 'New',
        last_name: 'User',
        new_password: DEFAULT_PASSWORD,
        is_active: 'true'
      }
      role_ids_to_set = [test_role.role_id.to_s]

      create_user_via_api(user_details, role_ids_to_set)
      expect(response_status).to eq(201)

      user = User.first(username: 'newuser')
      expect(user).not_to be_nil
      expect(user.email).to eq('newuser@example.com')
      expect(user.first_name).to eq('New')
      expect(user.last_name).to eq('User')
      expect(user.roles.map(&:role_id)).to include(test_role.role_id)
    end

    it 'prevents creating users with duplicate usernames' do
      user_details = {
        username: 'uniqueuser',
        email: 'unique@example.com',
        first_name: 'Unique',
        last_name: 'User',
        new_password: DEFAULT_PASSWORD,
        is_active: 'true'
      }
      role_ids_to_set = [test_role.role_id.to_s]

      create_user_via_api(user_details, role_ids_to_set)
      expect(response_status).to eq(201)

      create_user_via_api(user_details, role_ids_to_set)
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
      update_details = {
        username: 'updateduser',
        email: 'updated@example.com',
        first_name: 'Updated',
        last_name: 'User'
      }
      current_role_ids = test_user.roles.map { |r| r.role_id.to_s }

      update_user_via_api(test_user.user_id, update_details, current_role_ids)
      expect(response_status).to eq(200)

      updated_user = User.first(user_id: test_user.user_id)
      expect(updated_user.username).to eq('updateduser')
      expect(updated_user.email).to eq('updated@example.com')
      expect(updated_user.first_name).to eq('Updated')
      expect(updated_user.last_name).to eq('User')
    end

    it 'updates password when provided' do
      update_details_with_password = {
        new_password: 'newpa$$worD123!',
        password_confirmation: 'newpa$$worD123!'
      }
      current_role_ids = test_user.roles.map { |r| r.role_id.to_s }
      update_user_via_api(test_user.user_id, update_details_with_password, current_role_ids)
      expect(response_status).to eq(200)
    end

    it 'prevents updating to an already used username' do
      update_data_details = {
        username: regular_user.username,
        email: test_user.email,
        first_name: test_user.first_name,
        last_name: test_user.last_name
      }
      role_ids_for_update = [test_role.role_id.to_s]

      update_user_via_api(test_user.user_id, update_data_details, role_ids_for_update)
      expect(response_status).to eq(422)
    end

    it 'returns an error if the user does not exist' do
      update_data_details = {
        username: 'nonexistent',
        email: 'nonexistent@example.com',
        first_name: 'Non',
        last_name: 'Existent'
      }
      role_ids_for_update = [test_role.role_id.to_s]

      update_user_via_api(9999, update_data_details, role_ids_for_update)
      expect(response_status).to eq(404)
    end

    it 'updates user roles' do
      new_role = Fabricate(:role, role_name: 'NewRole')
      user_details_unchanged = {
        username: test_user.username,
        email: test_user.email
      }
      new_role_ids = [new_role.role_id.to_s]

      update_user_via_api(test_user.user_id, user_details_unchanged, new_role_ids)
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
      logout
      login_as(admin_user)

      user_details_for_admin_creation = {
        username: 'adminuser',
        email: 'adminuser@example.com',
        first_name: 'Admin',
        last_name: 'Created',
        new_password: DEFAULT_PASSWORD,
        is_active: 'true'
      }
      role_ids_for_admin_creation = [test_role.role_id.to_s]

      create_user_via_api(user_details_for_admin_creation, role_ids_for_admin_creation)
      expect(response_status).to eq(201)

      created_user = User.first(username: 'adminuser')
      expect(created_user).not_to be_nil

      logout
      login_as(regular_user)

      update_details_by_regular = {
        username: 'hacked',
        email: 'hacked@example.com',
        first_name: 'Hacked',
        last_name: 'User'
      }
      roles_for_regular_attempt = [test_role.role_id.to_s]

      update_user_via_api(created_user.user_id, update_details_by_regular, roles_for_regular_attempt)
      expect(response_status).to eq(403)
    end

    it 'denies regular users to DELETE /admin/users/:id' do
      logout
      login_as(admin_user)

      user_details_for_delete_test = {
        username: 'deletetest',
        email: 'deletetest@example.com',
        first_name: 'Delete',
        last_name: 'Test',
        new_password: DEFAULT_PASSWORD,
        is_active: 'true'
      }
      role_ids_for_delete_test = [test_role.role_id.to_s]

      create_user_via_api(user_details_for_delete_test, role_ids_for_delete_test)
      expect(response_status).to eq(201)

      created_user = User.first(username: 'deletetest')
      expect(created_user).not_to be_nil

      logout
      login_as(regular_user)

      delete_user_via_api(created_user.user_id)
      expect(response_status).to eq(403)
    end
  end
end
