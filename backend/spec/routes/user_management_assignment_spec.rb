# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Admin User Management Assignments API' do
  let!(:admin_user) { create_admin_user(username: 'admin_assign', email: 'admin_assign@example.com') }
  let!(:regular_user) { create_regular_user(username: 'user_assign', email: 'user_assign@example.com') }
  let!(:target_user) { create_regular_user(username: 'target_assign', email: 'target_assign@example.com') }

  let!(:product) { create_product_via_dao(name: 'Assignable Product') }
  let!(:license_type) { create_license_type_via_dao(name: 'Assignable Type') }

  let!(:license1) do
    create_license_via_dao(
      product: product,
      license_type: license_type,
      key: 'ASSIGN-L1',
      name: 'License One for Assignment',
      seats: 5
    )
  end
  let!(:license2) do
    create_license_via_dao(
      product: product,
      license_type: license_type,
      key: 'ASSIGN-L2',
      name: 'License Two for Assignment (Full)',
      seats: 1
    )
  end
  let!(:inactive_license) do
    create_license_via_dao(
      product: product,
      license_type: license_type,
      key: 'ASSIGN-L-INACTIVE',
      name: 'Inactive License',
      seats: 5,
      expire_date: Date.today - 1
    )
  end

  let!(:assignment_to_target_user_inactive) do
    create_assignment_via_dao(
      user: target_user,
      license: license1,
      is_active: false
    )
  end

  let!(:assignment_to_target_user_active) do
    create_assignment_via_dao(
      user: target_user,
      license: license2,
      is_active: true
    )
  end

  def get_user_assignments_page_api(user_id)
    get "/admin/users/#{user_id}/assignments"
  end

  def activate_assignment_api(user_id, assignment_id)
    put "/admin/users/#{user_id}/assignments/#{assignment_id}/activate"
  end

  def deactivate_assignment_api(user_id, assignment_id)
    put "/admin/users/#{user_id}/assignments/#{assignment_id}/deactivate"
  end

  def get_available_licenses_api(user_id)
    get "/admin/users/#{user_id}/available_licenses"
  end

  def create_assignment_api(user_id, license_id)
    post "/admin/users/#{user_id}/assignments", { license_id: license_id }
  end

  def delete_assignment_api(user_id, assignment_id)
    delete "/admin/users/#{user_id}/assignments/#{assignment_id}"
  end

  before(:each) do
    AssignmentLog.dataset.delete
    login_as(admin_user)
  end

  shared_examples 'admin assignment access only' do |http_method, path_generating_proc, params = {}|
    it 'redirects unauthenticated users to login' do
      logout
      path = instance_exec(&path_generating_proc)
      send(http_method, path, params)
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end

    it 'returns 403 for non-admin users' do
      login_as(regular_user)
      path = instance_exec(&path_generating_proc)
      send(http_method, path, params)
      expect(last_response.status).to eq(403)
    end
  end

  describe 'GET /admin/users/:user_id/assignments' do
    include_examples 'admin assignment access only', :get,
                     -> { "/admin/users/#{target_user.user_id}/assignments" }

    context 'when logged in as admin' do
      it 'displays the user assignments page with assignments' do
        get_user_assignments_page_api(target_user.user_id)
        expect(last_response.status).to eq(200)
        expect(last_response.body).to include("Assignments for #{target_user.username}")
        expect(last_response.body).to include(license1.license_key)
        expect(last_response.body).to include(license2.license_key)
      end

      it 'returns 404 if user not found' do
        get_user_assignments_page_api(99_999)
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'PUT /admin/users/:user_id/assignments/:assignment_id/activate' do
    let(:path_proc) do
      lambda {
        "/admin/users/#{target_user.user_id}/assignments/#{assignment_to_target_user_inactive.assignment_id}/activate"
      }
    end
    include_examples 'admin assignment access only', :put, -> { instance_exec(&path_proc) }

    context 'when logged in as admin' do
      it 'activates the assignment and logs the event' do
        expect do
          activate_assignment_api(target_user.user_id, assignment_to_target_user_inactive.assignment_id)
        end.to change { AssignmentLog.count }.by(1)

        expect(last_response.status).to eq(200)
        expect(flash[:success]).to eq('License assignment activated successfully.')
        assignment_to_target_user_inactive.reload
        expect(assignment_to_target_user_inactive.is_active).to be true

        log_entry = AssignmentLog.last
        expect(log_entry.action).to eq(AssignmentLogDAO::Actions::ADMIN_ACTIVATED)
        expect(log_entry.user_id).to eq(target_user.user_id)
        expect(log_entry.license_id).to eq(license1.license_id)
      end

      it 'returns 404 if assignment not found' do
        activate_assignment_api(target_user.user_id, 99_999)
        expect(last_response.status).to eq(404)
        expect(flash[:error]).to include('License Assignment (ID: 99999) not found')
      end

      it 'returns 409 if license has no available seats' do
        another_user = create_regular_user(username: 'another_seat_user', email: 'another@seat.com')
        new_inactive_assignment_full_license = create_assignment_via_dao(
          user: another_user,
          license: license2,
          is_active: false
        )

        activate_assignment_api(another_user.user_id, new_inactive_assignment_full_license.assignment_id)
        expect(last_response.status).to eq(409)
        expect(flash[:error]).to include("No available seats for license '#{license2.license_name}'")
      end

      it 'returns 409 if license is not active (e.g., expired)' do
        inactive_assignment_for_inactive_license = create_assignment_via_dao(
          user: target_user,
          license: inactive_license,
          is_active: false
        )
        activate_assignment_api(target_user.user_id, inactive_assignment_for_inactive_license.assignment_id)
        expect(last_response.status).to eq(409)
        expect(flash[:error]).to include("License '#{inactive_license.license_name}' is not active and cannot be activated.")
      end

      it 'returns 400 if assignment is already active' do
        activate_assignment_api(target_user.user_id, assignment_to_target_user_active.assignment_id)
        expect(last_response.status).to eq(400)
        expect(flash[:error]).to include('License assignment is already active.')
      end
    end
  end

  describe 'PUT /admin/users/:user_id/assignments/:assignment_id/deactivate' do
    let(:path_proc) do
      lambda {
        "/admin/users/#{target_user.user_id}/assignments/#{assignment_to_target_user_active.assignment_id}/deactivate"
      }
    end
    include_examples 'admin assignment access only', :put, -> { instance_exec(&path_proc) }

    context 'when logged in as admin' do
      it 'deactivates the assignment and logs the event' do
        expect do
          deactivate_assignment_api(target_user.user_id, assignment_to_target_user_active.assignment_id)
        end.to change { AssignmentLog.count }.by(1)

        expect(last_response.status).to eq(200)
        expect(flash[:success]).to eq('License assignment deactivated successfully.')
        assignment_to_target_user_active.reload
        expect(assignment_to_target_user_active.is_active).to be false

        log_entry = AssignmentLog.last
        expect(log_entry.action).to eq(AssignmentLogDAO::Actions::ADMIN_DEACTIVATED)
      end

      it 'returns 400 if assignment is already inactive' do
        deactivate_assignment_api(target_user.user_id, assignment_to_target_user_inactive.assignment_id)
        expect(last_response.status).to eq(400)
        expect(flash[:error]).to include("License assignment (ID: #{assignment_to_target_user_inactive.assignment_id}) is already inactive.")
      end

      it 'returns 404 if assignment not found' do
        deactivate_assignment_api(target_user.user_id, 99_999)
        expect(last_response.status).to eq(404)
        expect(flash[:error]).to include('License Assignment (ID: 99999) not found')
      end
    end
  end

  describe 'GET /admin/users/:user_id/available_licenses' do
    let!(:unassigned_available_license) do
      create_license_via_dao(product: product, license_type: license_type, key: 'UNASSIGNED-AVAIL',
                             name: 'Unassigned Available', seats: 3)
    end
    let!(:unassigned_unavailable_license) do
      create_license_via_dao(product: product, license_type: license_type, key: 'UNASSIGNED-UNAVAIL',
                             name: 'Unassigned Unavailable', seats: 3, expire_date: Date.today - 1)
    end

    include_examples 'admin assignment access only', :get,
                     -> { "/admin/users/#{target_user.user_id}/available_licenses" }

    context 'when logged in as admin' do
      it 'returns available licenses for the user as JSON' do
        get_available_licenses_api(target_user.user_id)
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to eq('application/json')

        json_response = JSON.parse(last_response.body)
        expect(json_response).to be_an(Array)

        license_names = json_response.map { |l| l['license_name'] }
        expect(license_names).not_to include(license1.license_name)
        expect(license_names).not_to include(license2.license_name)

        expect(license_names).to include(unassigned_available_license.license_name)
        expect(license_names).not_to include(unassigned_unavailable_license.license_name)

        available_lic = json_response.find { |l| l['license_id'] == unassigned_available_license.license_id }
        expect(available_lic).not_to be_nil
        expect(available_lic['available_seats']).to eq(unassigned_available_license.seat_count)
      end

      it 'returns 404 if user not found' do
        get_available_licenses_api(99_999)
        expect(last_response.status).to eq(404)
        expect(last_response.content_type).to eq('application/json')
        json_response = JSON.parse(last_response.body)
        expect(json_response['error']).to eq('User (ID: 99999) not found.')
      end
    end
  end

  describe 'POST /admin/users/:user_id/assignments' do
    let!(:assignable_license) do
      create_license_via_dao(product: product, license_type: license_type, key: 'ASSIGNABLE-NEW',
                             name: 'Fresh License', seats: 1)
    end

    include_examples 'admin assignment access only', :post,
                     -> { "/admin/users/#{target_user.user_id}/assignments" },
                     { license_id: 0 }

    context 'when logged in as admin' do
      it 'creates a new inactive assignment and logs the event' do
        expect do
          create_assignment_api(target_user.user_id, assignable_license.license_id)
        end.to change(LicenseAssignment, :count).by(1).and change(AssignmentLog, :count).by(1)

        expect(last_response.status).to eq(200)
        expect(flash[:success]).to eq('License assignment created successfully. It may need to be activated.')

        new_assignment = LicenseAssignment.last
        expect(new_assignment.user_id).to eq(target_user.user_id)
        expect(new_assignment.license_id).to eq(assignable_license.license_id)
        expect(new_assignment.is_active).to be false

        log_entry = AssignmentLog.last
        expect(log_entry.action).to eq(AssignmentLogDAO::Actions::ADMIN_APPROVED)
      end

      it 'returns 404 if user not found' do
        create_assignment_api(99_999, assignable_license.license_id)
        expect(last_response.status).to eq(404)
        expect(flash[:error]).to include('User (ID: 99999) not found')
      end

      it 'returns 404 if license not found' do
        create_assignment_api(target_user.user_id, 99_999)
        expect(last_response.status).to eq(404)
        expect(flash[:error]).to include('License (ID: 99999) not found')
      end

      it 'returns 409 if license already assigned to this user (even if inactive)' do
        create_assignment_api(target_user.user_id, license1.license_id)
        expect(last_response.status).to eq(409)
        expect(flash[:error]).to include("User already has an assignment for license '#{license1.license_name}'")
      end
    end
  end

  describe 'DELETE /admin/users/:user_id/assignments/:assignment_id' do
    let!(:deletable_assignment_license) do
      create_license_via_dao(product: product, license_type: license_type, key: 'DELETABLE-LIC',
                             name: 'Deletable License', seats: 1)
    end
    let!(:deletable_assignment) do
      create_assignment_via_dao(
        user: target_user,
        license: deletable_assignment_license,
        is_active: false
      )
    end

    include_examples 'admin assignment access only', :delete,
                     -> { "/admin/users/#{target_user.user_id}/assignments/#{deletable_assignment.assignment_id}" }

    context 'when logged in as admin' do
      it 'deletes an inactive assignment and logs the event' do
        expect do
          delete_assignment_api(target_user.user_id, deletable_assignment.assignment_id)
        end.to change(LicenseAssignment, :count).by(-1).and change(AssignmentLog, :count).by(1)

        expect(last_response.status).to eq(200)
        expect(flash[:success]).to eq('License assignment canceled successfully.')

        expect(LicenseAssignment[deletable_assignment.assignment_id]).to be_nil

        log_entry = AssignmentLog.last
        expect(log_entry.action).to eq(AssignmentLogDAO::Actions::ADMIN_CANCELED)
      end

      it 'returns 404 if assignment not found' do
        delete_assignment_api(target_user.user_id, 99_999)
        expect(last_response.status).to eq(404)
        expect(flash[:error]).to include('License Assignment (ID: 99999) not found.')
      end

      it 'returns 400 if trying to delete an active assignment' do
        delete_assignment_api(target_user.user_id, assignment_to_target_user_active.assignment_id)
        expect(last_response.status).to eq(400)
        expect(flash[:error]).to eq('Cannot cancel an active assignment. Deactivate it first.')
        expect(LicenseAssignment[assignment_to_target_user_active.assignment_id]).not_to be_nil
      end
    end
  end
end
