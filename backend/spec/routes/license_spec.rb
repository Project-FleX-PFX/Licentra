# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'License Routes' do
  let!(:admin_user) { create_admin_user }
  let!(:regular_user) { create_regular_user(email: 'licenseuser@example.com', username: 'licenseuser') }
  let!(:other_user) { create_regular_user(email: 'otheruser@example.com', username: 'otheruser') }

  let!(:product_word) { create_product_via_dao(name: 'Microsoft Word') }
  let!(:product_ppt) { create_product_via_dao(name: 'Microsoft PowerPoint') }
  let!(:license_type_single) { create_license_type_via_dao(name: 'Single User') }

  let!(:word_license_available) do
    create_license_via_dao(
      product: product_word,
      license_type: license_type_single,
      name: 'Word Pro License',
      key: 'WORD-PRO-123',
      seats: 2
    )
  end

  let!(:word_license_no_seats) do
    lic = create_license_via_dao(
      product: product_word,
      license_type: license_type_single,
      name: 'Word Basic (No Seats)',
      key: 'WORD-BASIC-SETUP-KEY',
      seats: 1
    )
    LicenseAssignmentDAO.create(license_id: lic.license_id, user_id: admin_user.user_id, is_active: true)
    lic.refresh
    expect(lic.available_seats).to eq(0)
    lic
  end

  let!(:ppt_license_inactive) do
    create_license_via_dao(
      product: product_ppt,
      license_type: license_type_single,
      name: 'PowerPoint Old',
      key: 'PPT-OLD-456',
      seats: 5,
      expire_date: Date.today - 1,
    )
  end

  before(:each) do
    login_as(regular_user)
  end

  describe 'GET /licenses (Available Licenses)' do
    it 'displays available licenses to a logged-in user' do
      get '/licenses'
      expect(response_status).to eq(200)
      expect(response_body).to include('Available Licenses')
      expect(response_body).to include(product_word.product_name)
      expect(response_body).not_to include(word_license_no_seats.license_name)
      expect(response_body).not_to include(ppt_license_inactive.license_name)
    end

    it 'redirects unauthenticated users to login' do
      logout
      get '/licenses'
      expect(response_status).to be(302)
      expect(last_response.location).to include('/login')
    end
  end

  describe 'POST /licenses/:license_id/assign' do
    context 'with a valid and available license' do
      it 'assigns the license to the current user and shows success message on my-licenses page' do
        expect do
          post "/licenses/#{word_license_available.license_id}/assign"
        end.to change {
                 LicenseAssignment.where(user_id: regular_user.user_id, license_id: word_license_available.license_id,
                                         is_active: true).count
               }.by(1)

        expect(response_status).to be(302)
        expect(last_response.location).to include('/my-licenses')
        follow_redirect!

        expect(response_status).to eq(200)
        expect(response_body).to include('License successfully assigned')

        log = AssignmentLog.last
        expect(log).not_to be_nil
        expect(log.assignment_id).not_to be_nil
        expect(log.action).to eq('ASSIGNED_SELF')
        expect(log.details).to include(regular_user.username)
        expect(log.details).to include(word_license_available.license_name)
      end

      it 'decreases available seats (implicitly tested by assignment)' do
        initial_available_seats = word_license_available.reload.available_seats
        post "/licenses/#{word_license_available.license_id}/assign"
        expect(word_license_available.reload.available_seats).to eq(initial_available_seats - 1)
      end
    end

    context 'when license is not available' do
      it 'does not assign a license with no available seats and shows an error on licenses page' do
        post "/licenses/#{word_license_no_seats.license_id}/assign"
        expect(response_status).to be(302)
        expect(last_response.location).to include('/licenses')
        follow_redirect!

        expect(response_status).to be(200)
        expected_error_message = "No available seats for license '#{word_license_no_seats.license_name}'."
        expect(response_body).to include(expected_error_message)
        expect(LicenseAssignment.where(user_id: regular_user.user_id,
                                       license_id: word_license_no_seats.license_id).count).to eq(0)
      end

      it 'does not assign an inactive license and shows an error on licenses page' do
        post "/licenses/#{ppt_license_inactive.license_id}/assign"
        expect(response_status).to be(302)
        expect(last_response.location).to include('/licenses')
        follow_redirect!

        expect(response_status).to eq(200)
        expect(response_body).to include('is not active')
      end
    end

    it 'prevents assigning a license the user already has active and shows error on licenses page' do
      post "/licenses/#{word_license_available.license_id}/assign"
      follow_redirect!
      expect(LicenseAssignment.where(user_id: regular_user.user_id, license_id: word_license_available.license_id,
                                     is_active: true).count).to eq(1)

      post "/licenses/#{word_license_available.license_id}/assign"
      expect(response_status).to be(302)
      expect(last_response.location).to include('/licenses')
      follow_redirect!

      expect(response_status).to eq(200)
      expected_error_message = "You already have license '#{word_license_available.license_name}' assigned and active."
      expect(response_body).to include(expected_error_message)
      expect(LicenseAssignment.where(user_id: regular_user.user_id, license_id: word_license_available.license_id,
                                     is_active: true).count).to eq(1)
    end

    it 'redirects unauthenticated users to login' do
      logout
      post "/licenses/#{word_license_available.license_id}/assign"
      expect(response_status).to be(302)
      expect(last_response.location).to include('/login')
    end
  end

  describe 'GET /my-licenses' do
    let!(:assignment_for_user) do
      LicenseAssignmentDAO.create(
        license_id: word_license_available.license_id,
        user_id: regular_user.user_id,
        is_active: true
      )
    end
    let!(:assignment_for_other_user) do
      LicenseAssignmentDAO.create(
        license_id: ppt_license_inactive.license_id,
        user_id: other_user.user_id,
        is_active: true
      )
    end

    it 'displays licenses assigned to the current user' do
      get '/my-licenses'
      expect(response_status).to eq(200)
      expect(response_body).to include('My Licenses')
      expect(response_body).to include(product_word.product_name)
      expect(response_body).not_to include(ppt_license_inactive.license_name)
    end

    it 'shows "no licenses" message if user has no active assignments' do
      assignment_for_user.update(is_active: false)
      get '/my-licenses'
      expect(response_status).to eq(200)
      expect(response_body).to include('You do not have any licenses assigned')
    end

    it 'redirects unauthenticated users to login' do
      logout
      get '/my-licenses'
      expect(response_status).to be(302)
      expect(last_response.location).to include('/login')
    end
  end

  describe 'POST /my-licenses/:assignment_id/return' do
    let!(:active_assignment) do
      LicenseAssignmentDAO.create(
        license_id: word_license_available.license_id,
        user_id: regular_user.user_id,
        is_active: true
      )
    end

    context 'when returning a valid, active assignment belonging to the user' do
      it 'deactivates the assignment and shows success message on my-licenses page' do
        expect do
          post "/my-licenses/#{active_assignment.assignment_id}/return"
        end.to change { active_assignment.reload.is_active }.from(true).to(false)

        expect(response_status).to be(302)
        expect(last_response.location).to include('/my-licenses')
        follow_redirect!

        expect(response_status).to eq(200)
        expect(response_body).to include('License successfully returned')

        log = AssignmentLog.last
        expect(log).not_to be_nil
        expect(log.assignment_id).to eq(active_assignment.assignment_id)
        expect(log.action).to eq('RETURNED_SELF')
      end

      it 'makes a seat available again (implicitly)' do
        initial_available_seats = word_license_available.reload.available_seats
        post "/my-licenses/#{active_assignment.assignment_id}/return"
        expect(word_license_available.reload.available_seats).to eq(initial_available_seats + 1)
      end
    end

    it 'prevents returning an assignment that does not belong to the user and shows error on my-licenses page' do
      assignment_of_other_user = LicenseAssignmentDAO.create(license_id: word_license_available.license_id,
                                                             user_id: other_user.user_id, is_active: true)
      post "/my-licenses/#{assignment_of_other_user.assignment_id}/return"
      expect(response_status).to be(302)
      expect(last_response.location).to include('/my-licenses')
      follow_redirect!

      expect(response_status).to eq(200)
      expect(response_body).to include('This license assignment does not belong to you.')
      expect(assignment_of_other_user.reload.is_active).to be true
    end

    it 'shows an error if trying to return an already inactive assignment' do
      active_assignment.update(is_active: false)
      post "/my-licenses/#{active_assignment.assignment_id}/return"

      expect(response_status).to be(302)
      follow_redirect!

      expect(response_status).to eq(200)
      expect(response_body).to include('<div class="alert error">')
      expect(response_body).to include('already inactive')
    end

    it 'redirects unauthenticated users to login' do
      logout
      post "/my-licenses/#{active_assignment.assignment_id}/return"
      expect(response_status).to be(302)
      expect(last_response.location).to include('/login')
    end
  end
end
