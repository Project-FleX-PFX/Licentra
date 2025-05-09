# frozen_string_literal: true

# Module for routes within license context
module LicenseRoutes
  def self.registered(app)
    app.get '/licenses' do
      require_login
      require_role('User')

      @title = 'Available Licenses'
      @css   = 'licenses'

      @available_licenses = LicenseDAO.find_available_for_assignment

      erb :'licenses/available'
    end

    app.post '/licenses/:license_id/assign' do
      require_login
      require_role('User')

      license_id = params[:license_id].to_i
      user = current_user

      begin
        LicenseService.assign_license_to_user(license_id, user)
        flash[:success] = 'License successfully assigned!'
        redirect '/my-licenses'
      rescue LicenseService::ServiceError, ArgumentError => e
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

    app.post '/my-licenses/:assignment_id/return' do
      require_login
      assignment_id = params[:assignment_id].to_i
      user = current_user

      begin
        LicenseService.return_license_from_user(assignment_id, user)
        flash[:success] = 'License successfully returned!'
      rescue LicenseService::ServiceError, ArgumentError => e
        flash[:error] = e.message
      rescue StandardError => e
        logger.error "Unexpected error during license return: #{e.message}\n#{e.backtrace.join("\n")}"
        flash[:error] = 'An unexpected error occurred. Please try again.'
      ensure
        redirect '/my-licenses'
      end
    end
  end
end
