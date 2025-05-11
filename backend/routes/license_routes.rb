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
        LicenseAssignmentDAO.activate(license_assignment_id)

        # Hier holst du das Assignment nach der Aktivierung
        assignment = LicenseAssignmentDAO.find(license_assignment_id)

        # Korrigierte Details mit den richtigen Attributen
        details = "User '#{user.username}' (ID: #{user.user_id}) performed action 'USER_ACTIVATE' " \
          "for license '#{assignment.license.license_name}' (License ID: #{assignment.license.license_id}). " \
          "Assignment ID: #{license_assignment_id}."

        # Korrigierte Parameter für das Log
        AssignmentLogDAO.create(
          assignment_id: license_assignment_id,
          action: 'USER_ACTIVATE', # Hier war 'ADMIN_DELETED', was nicht zum Kontext passt
          details: details
        )

        flash[:success] = 'License successfully activated.'
        redirect '/my-licenses'
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
        LicenseAssignmentDAO.deactivate(license_assignment_id)

        # Hier holst du das Assignment nach der Deaktivierung
        assignment = LicenseAssignmentDAO.find(license_assignment_id)

        # Korrigierte Details mit den richtigen Attributen
        details = "User '#{user.username}' (ID: #{user.user_id}) performed action 'USER_DEACTIVATE' " \
          "for license '#{assignment.license.license_name}' (License ID: #{assignment.license.license_id}). " \
          "Assignment ID: #{license_assignment_id}."

        # Korrigierte Parameter für das Log
        AssignmentLogDAO.create(
          assignment_id: license_assignment_id,
          action: 'USER_DEACTIVATE',
          details: details
        )

        flash[:success] = 'License successfully deactivated.'
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
