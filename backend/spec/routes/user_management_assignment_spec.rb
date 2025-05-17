# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'User Management Assignments API' do
  include IntegrationHelpers

  # --- Test User Setup ---
  let!(:admin_user) { create_admin_user }
  let!(:regular_user) { create_regular_user }
  let!(:test_role) { Fabricate(:role, role_name: 'TestRole') }
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
  let!(:test_product) { create_product_via_dao(name: 'Test Product') }
  let!(:test_license_type) { create_license_type_via_dao(name: 'Test License Type') }
  let!(:test_license) do
    create_license_via_dao(product: test_product,
                           license_type: test_license_type,
                           key: "TESTKEY-#{SecureRandom.hex(4)}",
                           name: 'Test License',
                           seats: 5)
  end

  def create_assignment_via_api(user_id, license_id)
    post "/user_management/#{user_id}/assignments", { license_id: license_id }
  end

  def toggle_assignment_status_via_api(user_id, assignment_id, is_active)
    put "/user_management/#{user_id}/assignments/#{assignment_id}/toggle_status", { is_active: is_active.to_s }
  end

  def delete_assignment_via_api(user_id, assignment_id)
    delete "/user_management/#{user_id}/assignments/#{assignment_id}"
  end

  before(:each) do
    # Bereinige die Benutzertabelle, aber behalte Admin, Regular und Test User
    User.exclude(user_id: [admin_user.user_id, regular_user.user_id, test_user.user_id]).delete
    # Bereinige Zuweisungen und Logs
    LicenseAssignment.dataset.delete
    AssignmentLog.dataset.delete
    login_as(admin_user)
  end

  describe 'GET /user_management/:user_id/assignments' do
    it 'displays the user assignments page for an existing user' do
      get "/user_management/#{test_user.user_id}/assignments"
      expect(response_status).to be(200)
      expect(response_body).to include(test_user.username)
    end

    it 'returns 404 for a non-existing user' do
      get '/user_management/9999/assignments'
      expect(response_status).to eq(404)
      expect(response_body).to include('User not found')
    end

    it 'denies access for unauthenticated users' do
      logout
      get "/user_management/#{test_user.user_id}/assignments"
      expect(response_status).to be(302)
      expect(last_response.location).to include('/login')
    end

    it 'denies access for non-admin users' do
      logout
      login_as(regular_user)
      get "/user_management/#{test_user.user_id}/assignments"
      expect(response_status).to eq(403)
    end
  end

  describe 'GET /user_management/:user_id/available_licenses' do
    it 'returns available licenses for an existing user as JSON' do
      get "/user_management/#{test_user.user_id}/available_licenses"
      expect(response_status).to eq(200)

      response_data = JSON.parse(response_body)
      expect(response_data).to be_an(Array)
      expect(response_data.any? { |l| l['license_id'] == test_license.license_id }).to be true
    end

    it 'excludes already assigned licenses' do
      # Erstelle eine Zuweisung
      create_assignment_via_api(test_user.user_id, test_license.license_id)
      expect(response_status).to eq(200)

      get "/user_management/#{test_user.user_id}/available_licenses"
      expect(response_status).to eq(200)

      response_data = JSON.parse(response_body)
      expect(response_data.any? { |l| l['license_id'] == test_license.license_id }).to be false
    end

    it 'returns 404 for a non-existing user' do
      get '/user_management/9999/available_licenses'
      expect(response_status).to eq(404)
      expect(response_body).to include('User not found')
    end

    it 'denies access for non-admin users' do
      logout
      login_as(regular_user)
      get "/user_management/#{test_user.user_id}/available_licenses"
      expect(response_status).to eq(403)
    end
  end

  describe 'POST /user_management/:user_id/assignments' do
    it 'creates a new license assignment for an existing user' do
      create_assignment_via_api(test_user.user_id, test_license.license_id)
      expect(response_status).to eq(200)
      expect(last_request.env['x-rack.flash'][:success]).to eq('License assignment successfully created (inactive)')

      assignment = LicenseAssignment.first(user_id: test_user.user_id, license_id: test_license.license_id)
      expect(assignment).not_to be_nil
      expect(assignment.is_active).to be false

      log = AssignmentLog.first(assignment_id: assignment.assignment_id)
      expect(log).not_to be_nil
      expect(log.action).to eq(AssignmentLogDAO::Actions::ADMIN_APPROVED)
    end

    it 'returns 404 for a non-existing user' do
      create_assignment_via_api(9999, test_license.license_id)
      expect(response_status).to eq(404)
      expect(response_body).to include('User not found')
    end

    it 'returns 500 for an invalid license' do
      create_assignment_via_api(test_user.user_id, 9999)
      expect(response_status).to eq(500)
      expect(response_body).to include('Error creating license assignment')
    end

    it 'denies access for non-admin users' do
      logout
      login_as(regular_user)
      create_assignment_via_api(test_user.user_id, test_license.license_id)
      expect(response_status).to eq(403)
    end
  end

  describe 'PUT /user_management/:user_id/assignments/:assignment_id/toggle_status' do
    let!(:assignment) do
      assign = LicenseAssignmentDAO.create(
        license_id: test_license.license_id,
        user_id: test_user.user_id,
        assignment_date: Time.now,
        is_active: false
      )
      assign
    end

    it 'activates an inactive assignment' do
      toggle_assignment_status_via_api(test_user.user_id, assignment.assignment_id, true)
      expect(response_status).to eq(200)
      expect(last_request.env['x-rack.flash'][:success]).to eq('License assignment successfully activated')

      updated_assignment = LicenseAssignment.first(assignment_id: assignment.assignment_id)
      expect(updated_assignment.is_active).to be true

      log = AssignmentLog.first(assignment_id: assignment.assignment_id,
                                action: AssignmentLogDAO::Actions::ADMIN_ACTIVATED)
      expect(log).not_to be_nil
    end

    it 'deactivates an active assignment' do
      # Erst aktivieren
      LicenseAssignmentDAO.activate(assignment.assignment_id)
      toggle_assignment_status_via_api(test_user.user_id, assignment.assignment_id, false)
      expect(response_status).to eq(200)
      expect(last_request.env['x-rack.flash'][:success]).to eq('License assignment successfully deactivated')

      updated_assignment = LicenseAssignment.first(assignment_id: assignment.assignment_id)
      expect(updated_assignment.is_active).to be false

      log = AssignmentLog.first(assignment_id: assignment.assignment_id,
                                action: AssignmentLogDAO::Actions::ADMIN_DEACTIVATED)
      expect(log).not_to be_nil
    end

    it 'returns 404 for a non-existing assignment' do
      toggle_assignment_status_via_api(test_user.user_id, 9999, true)
      expect(response_status).to eq(404)
      expect(response_body).to include('Assignment not found')
    end

    it 'returns 500 for an error during status change' do
      # Hier könnte man einen Fehler simulieren, aber da es schwierig ist, einen Fehler zu erzwingen,
      # testen wir nur den Statuscode bei einem generischen Fehler
      allow(LicenseAssignmentDAO).to receive(:activate).and_raise(StandardError.new('Test Error'))
      toggle_assignment_status_via_api(test_user.user_id, assignment.assignment_id, true)
      expect(response_status).to eq(500)
      expect(response_body).to include('Error changing assignment status')
    end

    it 'denies access for non-admin users' do
      logout
      login_as(regular_user)
      toggle_assignment_status_via_api(test_user.user_id, assignment.assignment_id, true)
      expect(response_status).to eq(403)
    end
  end

  describe 'DELETE /user_management/:user_id/assignments/:assignment_id' do
    let!(:assignment) do
      assign = LicenseAssignmentDAO.create(
        license_id: test_license.license_id,
        user_id: test_user.user_id,
        assignment_date: Time.now,
        is_active: false
      )
      assign
    end

    it 'deletes an inactive assignment' do
      assignment_id = assignment.assignment_id
      delete_assignment_via_api(test_user.user_id, assignment_id)
      expect(response_status).to eq(200)
      expect(last_request.env['x-rack.flash'][:success]).to eq('License assignment successfully deleted')

      deleted_assignment = LicenseAssignment.first(assignment_id: assignment_id)
      expect(deleted_assignment).to be_nil

      log = AssignmentLog.first(action: AssignmentLogDAO::Actions::ADMIN_CANCELED)
      expect(log).not_to be_nil
    end

    it 'returns 404 for a non-existing assignment' do
      delete_assignment_via_api(test_user.user_id, 9999)
      expect(response_status).to eq(404)
      expect(response_body).to include('Assignment not found')
    end

    it 'returns 400 for an active assignment' do
      # Aktiviere die Zuweisung
      LicenseAssignmentDAO.activate(assignment.assignment_id)
      delete_assignment_via_api(test_user.user_id, assignment.assignment_id)
      expect(response_status).to eq(400)
      expect(response_body).to include('Cannot delete active assignment')
    end

    it 'denies access for non-admin users' do
      logout
      login_as(regular_user)
      delete_assignment_via_api(test_user.user_id, assignment.assignment_id)
      expect(response_status).to eq(403)
    end
  end
end
