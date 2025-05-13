# frozen_string_literal: true

# Module for routes within license context
module LicenseRoutes
  def self.registered(app)
    app.get '/licenses' do
      require_login
      require_role('User')

      user = current_user

      @title = 'Available Licenses'
      @css   = 'licenses'

      @available_assignments = LicenseAssignmentDAO.find_inactive_for_user_with_details(user.user_id)

      erb :'licenses/available'
    end

    app.post '/licenses/:license_assignment_id/activate' do
      require_login
      require_role('User')

      license_assignment_id = params[:license_assignment_id].to_i
      user = current_user

      begin
        assignment = LicenseAssignmentDAO.find(license_assignment_id)

        raise ArgumentError, 'This license assignment does not belong to you' unless assignment.user_id == user.user_id

        raise DAO::ValidationError, 'This license assignment is already active' if assignment.is_active?

        raise DAO::ValidationError, 'No available seats' if assignment.license.available_seats <= 0

        LicenseAssignmentDAO.activate(license_assignment_id)

        assignment = LicenseAssignmentDAO.find(license_assignment_id)

        details = "User '#{user.username}' (ID: #{user.user_id}) performed action 'USER_ACTIVATED' " \
          "for license '#{assignment.license.license_name}' (License ID: #{assignment.license.license_id}). " \
          "Assignment ID: #{license_assignment_id}."

        AssignmentLogDAO.create(
          assignment_id: license_assignment_id,
          action: 'USER_ACTIVATED',
          details: details
        )

        flash[:success] = 'License successfully activated.'
        redirect '/my-licenses'
      rescue ArgumentError => e
        flash[:error] = e.message
        redirect '/licenses'
      rescue DAO::ValidationError => e
        flash[:error] = e.message
        redirect '/licenses'
      rescue StandardError => e
        logger.error "Unexpected error during license assignment: #{e.message}\n#{e.backtrace.join("\n")}"
        flash[:error] = 'An unexpected error occurred. Please try again.'
        redirect '/licenses'
      end
    end

    app.get '/my-licenses' do
      require_login
      user = current_user

      @title = 'My Licenses'
      @css   = 'my-licenses'

      @my_assignments = LicenseAssignmentDAO.find_active_for_user_with_details(user.user_id)

      erb :'licenses/my_licenses'
    end

    app.post '/my-licenses/:license_assignment_id/return' do
      require_login
      require_role('User')

      license_assignment_id = params[:license_assignment_id].to_i
      user = current_user

      begin
        assignment = LicenseAssignmentDAO.find(license_assignment_id)

        raise ArgumentError unless assignment.user_id == user.user_id

        raise DAO::ValidationError, 'This license assignment is already inactive' unless assignment.is_active?

        LicenseAssignmentDAO.deactivate(license_assignment_id)

        assignment = LicenseAssignmentDAO.find(license_assignment_id)

        details = "User '#{user.username}' (ID: #{user.user_id}) performed action 'USER_DEACTIVATED' " \
          "for license '#{assignment.license.license_name}' (License ID: #{assignment.license.license_id}). " \
          "Assignment ID: #{license_assignment_id}."

        AssignmentLogDAO.create(
          assignment_id: license_assignment_id,
          action: 'USER_DEACTIVATED',
          details: details
        )

        flash[:success] = 'License successfully deactivated.'
        redirect '/my-licenses'
      rescue ArgumentError
        flash[:error] = 'This license assignment does not belong to you'
        redirect '/my-licenses'
      rescue DAO::ValidationError => e
        flash[:error] = e.message
        redirect '/my-licenses'
      rescue StandardError => e
        logger.error "Unexpected error during license deactivation: #{e.message}\n#{e.backtrace.join("\n")}"
        flash[:error] = 'An unexpected error occurred. Please try again.'
        redirect '/my-licenses'
      end
    end
  end
end
