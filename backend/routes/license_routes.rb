# frozen_string_literal: true

require_relative '../services/license_service'
require_relative '../dao/license_assignment_dao'

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

      erb :'licenses/available', layout: :'layouts/application'
    end

    app.post '/licenses/:license_assignment_id/activate' do
      require_login
      require_role('User')

      license_assignment_id = params[:license_assignment_id].to_i
      user = current_user

      begin
        LicenseService.activate_license_for_user(license_assignment_id, user)

        flash[:success] = 'License successfully activated.'
        redirect '/my-licenses'
      rescue LicenseService::ServiceError => e
        flash[:error] = e.message
        redirect '/licenses'
      rescue StandardError => e
        logger.error "Unexpected error during license activation: #{e.message}\n#{e.backtrace.join("\n")}"
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

      erb :'licenses/index', layout: :'layouts/application'
    end

    app.post '/my-licenses/:license_assignment_id/return' do
      require_login
      require_role('User')

      license_assignment_id = params[:license_assignment_id].to_i
      user = current_user

      begin
        LicenseService.deactivate_license_for_user(license_assignment_id, user)

        flash[:success] = 'License successfully deactivated.'
        redirect '/my-licenses'
      rescue LicenseService::ServiceError => e
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
