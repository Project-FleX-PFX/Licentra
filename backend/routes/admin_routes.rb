# frozen_string_literal: true

require_relative '../services/license_service'
require_relative '../services/product_service'
require_relative '../services/user_service'

require_relative '../dao/product_dao'
require_relative '../dao/role_dao'
require_relative '../dao/user_dao'
require_relative '../dao/license_dao'

module AdminRoutes # rubocop:disable Metrics/ModuleLength
  def self.registered(app) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    app.before '/admin/*' do
      require_role('Admin')
    end

    # --- Product Management ---
    app.get '/admin/products' do
      @title = 'Manage Products'
      @products = ProductDAO.all(order: :product_name)
      erb :'admin/products/index', layout: :'layouts/application'
    end

    app.post '/admin/products' do
      product_params = params[:product] || {}
      handle_product_service_errors do
        created_product = ProductService.create_product_as_admin(product_params, current_user)
        flash[:success] = "Product '#{created_product.product_name}' created successfully."
      end
    end

    app.patch '/admin/products/:id' do
      product_id = params[:id].to_i
      product_params_from_form = params[:product] || {}

      handle_product_service_errors do
        updated_product = ProductService.update_product_as_admin(product_id, product_params_from_form, current_user)
        flash[:success] = "Product '#{updated_product.product_name}' updated successfully."
      end
    end

    app.delete '/admin/products/:id' do
      product_id = params[:id].to_i
      handle_product_service_errors(product_id: product_id) do
        product = ProductDAO.find!(product_id)
        ProductService.delete_product_as_admin(product_id, current_user)
        flash[:success] = "Product '#{product.product_name}' deleted successfully."
      end
    end

    # --- License Management ---
    app.get '/admin/licenses' do
      @title = 'Manage Licenses'
      order_criteria = [Sequel.asc(Sequel[:products][:product_name]), Sequel.asc(Sequel[:licenses][:license_name])]
      @licenses = LicenseDAO.all_with_details(order: order_criteria)

      @products = ProductDAO.all(order: :product_name)
      @license_types = LicenseTypeDAO.all(order: :type_name)

      erb :'admin/licenses/index', layout: :'layouts/application'
    end

    app.post '/admin/licenses' do
      license_params = params[:license] || {}
      begin
        LicenseService.create_license_as_admin(license_params, current_user)
        flash[:success] = 'License created successfully.'
      rescue LicenseService::LicenseManagementError => e
        flash[:error] = "Failed to create license: #{e.message}"
      end
      redirect '/admin/licenses'
    end

    app.patch '/admin/licenses/:id' do
      license_id = params[:id].to_i
      license_params_from_form = params[:license] || {}

      begin
        updated_license = LicenseService.update_license_as_admin(license_id, license_params_from_form, current_user)

        if updated_license
          flash[:success] =
            "License (ID: #{license_id}) updated successfully. New name: #{updated_license.license_name}"
        else
          flash[:error] = "License (ID: #{license_id}) update may have failed (no object returned)."
        end
      rescue LicenseService::LicenseManagementError => e
        flash[:error] = "Failed to update license: #{e.message}"
      rescue LicenseService::NotFoundError => e
        flash[:error] = e.message
      rescue StandardError => e
        flash[:error] = "An unexpected error occurred: #{e.message}"
        puts "UNEXPECTED ERROR in PATCH /admin/licenses/#{license_id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      end
      redirect '/admin/licenses'
    end

    app.delete '/admin/licenses/:id' do
      license_id = params[:id].to_i
      begin
        LicenseService.delete_license_as_admin(license_id, current_user)
        flash[:success] = "License (ID: #{license_id}) deleted successfully."
      rescue LicenseService::LicenseManagementError, LicenseService::NotFoundError => e
        flash[:error] = e.message
      end
      redirect '/admin/licenses'
    end

    # --- User Management by Admin ---
    app.get '/admin/users' do
      @title = 'Manage Users'
      @users = UserDAO.all_with_roles(order: :username)
      @roles = RoleDAO.all(order: :role_name)
      erb :'admin/users/index', layout: :'layouts/application'
    end

    app.post '/admin/users' do
      user_params_from_form = params[:user] || {}
      role_ids_from_form = params[:user_role_ids].is_a?(Array) ? params[:user_role_ids].map(&:to_i) : []
      service_params = user_params_from_form.merge(role_ids: role_ids_from_form)

      begin
        UserService.create_user_as_admin(service_params, current_user)
        flash[:success] = 'User created successfully.'
      rescue UserService::AdminProtectionError => e
        flash[:error] = e.message
      rescue UserService::UserManagementError => e
        flash[:error] = "Failed to create user: #{e.message}"
      end
      redirect '/admin/users'
    end

    app.patch '/admin/users/:id' do
      target_user_id = params[:id].to_i
      user_params_for_details = params[:user] || {}
      role_ids_from_form = params[:user_role_ids].is_a?(Array) ? params[:user_role_ids].map(&:to_i) : []

      begin
        UserService.update_user_details_as_admin(target_user_id, user_params_for_details, current_user)

        new_password_value = user_params_for_details[:new_password].to_s
        unless new_password_value.strip.empty?
          unless new_password_value == user_params_for_details[:password_confirmation]
            raise UserService::UserManagementError, 'Passwords do not match.'
          end

          UserService.reset_user_password_as_admin(target_user_id, new_password_value, current_user)
        end

        UserService.manage_user_roles_as_admin(target_user_id, role_ids_from_form, current_user)

        flash[:success] = "User (ID: #{target_user_id}) updated successfully."
      rescue UserService::AdminProtectionError => e
        flash[:error] = e.message
      rescue UserService::UserManagementError => e
        flash[:error] = "Failed to update user: #{e.message}"
      rescue UserService::NotFoundError => e
        flash[:error] = e.message
      end
      redirect '/admin/users'
    end

    app.post '/admin/users/:id/lock' do
      target_user_id = params[:id].to_i
      begin
        UserService.lock_user_as_admin(target_user_id, current_user)
        flash[:success] = "User (ID: #{target_user_id}) locked successfully."
      rescue UserService::UserManagementError, UserService::NotFoundError => e
        flash[:error] = e.message
      end
      redirect request.referrer || '/admin/users'
    end

    app.post '/admin/users/:id/unlock' do
      target_user_id = params[:id].to_i
      begin
        UserService.unlock_user_as_admin(target_user_id, current_user)
        flash[:success] = "User (ID: #{target_user_id}) unlocked successfully."
      rescue UserService::UserManagementError, UserService::NotFoundError => e
        flash[:error] = e.message
      end
      redirect request.referrer || '/admin/users'
    end

    app.delete '/admin/users/:id' do
      target_user_id = params[:id].to_i
      begin
        UserService.delete_user_as_admin(target_user_id, current_user)
        flash[:success] = "User (ID: #{target_user_id}) deleted successfully."
      rescue UserService::UserManagementError, UserService::NotFoundError => e
        flash[:error] = e.message
      end
      redirect '/admin/users'
    end

    # --- License Assignment Management by Admin ---
    app.get '/admin/users/:user_id/assignments' do
      @user_for_assignments_id = params[:user_id].to_i
      begin
        @user = UserDAO.find_by_id_with_roles!(@user_for_assignments_id)
        @title = "Manage License Assignments for #{@user.username}"
        @assignments = LicenseAssignmentDAO.find_detailed_by_user(@user_for_assignments_id)
        erb :'admin/users/assignments', layout: :'layouts/application'
      rescue DAO::RecordNotFound
        flash[:error] = "User (ID: #{@user_for_assignments_id}) not found."
        redirect '/admin/users'
      end
    end

    app.get '/admin/users/:user_id/available_licenses' do
      content_type :json
      user_id = params[:user_id].to_i
      begin
        UserDAO.find!(user_id)
        available_licenses = LicenseDAO.find_available_for_user_assignment(user_id)
        available_licenses.map(&:to_api_hash).to_json
      rescue DAO::RecordNotFound
        halt 404, { error: "User (ID: #{user_id}) not found." }.to_json
      rescue StandardError => e
        puts "ERROR fetching available licenses: #{e.message}"
        halt 500, { error: "Failed to load available licenses: #{e.message}" }.to_json
      end
    end

    app.post '/admin/users/:user_id/assignments' do
      target_user_id = params[:user_id].to_i
      license_id = params[:license_id].to_i
      begin
        LicenseService.approve_assignment_for_user(license_id, target_user_id, current_user)
        flash[:success] = 'License assignment created successfully. It may need to be activated.'
      rescue LicenseService::ServiceError => e
        flash[:error] = e.message
      end
      redirect back
    end

    app.put '/admin/users/:user_id/assignments/:assignment_id/activate' do
      user_id_param = params[:user_id].to_i
      assignment_id = params[:assignment_id].to_i
      begin
        assignment = LicenseAssignmentDAO.find!(assignment_id)
        if assignment.user_id != user_id_param
          raise LicenseService::NotAuthorizedError, 'Assignment does not belong to the specified user.'
        end

        LicenseService.activate_license_for_user(assignment_id, current_user)
        flash[:success] = "License assignment (ID: #{assignment_id}) activated."
      rescue LicenseService::ServiceError => e
        flash[:error] = e.message
      end
      redirect back
    end

    app.put '/admin/users/:user_id/assignments/:assignment_id/deactivate' do
      user_id_param = params[:user_id].to_i
      assignment_id = params[:assignment_id].to_i
      begin
        assignment = LicenseAssignmentDAO.find!(assignment_id)
        if assignment.user_id != user_id_param
          raise LicenseService::NotAuthorizedError, 'Assignment does not belong to the specified user.'
        end

        LicenseService.deactivate_license_for_user(assignment_id, current_user)
        flash[:success] = "License assignment (ID: #{assignment_id}) deactivated."
      rescue LicenseService::ServiceError => e
        flash[:error] = e.message
      end
      redirect back
    end

    app.delete '/admin/users/:user_id/assignments/:assignment_id' do
      user_id_param = params[:user_id].to_i
      assignment_id = params[:assignment_id].to_i
      begin
        assignment = LicenseAssignmentDAO.find!(assignment_id)
        if assignment.user_id != user_id_param
          raise LicenseService::NotAuthorizedError, 'Assignment does not belong to the specified user.'
        end

        LicenseService.cancel_assignment_as_admin(assignment_id, current_user)
        flash[:success] = "License assignment (ID: #{assignment_id}) canceled/deleted."
      rescue LicenseService::ServiceError => e
        flash[:error] = e.message
      end
      redirect back
    end

    # --- Special Routes ---
    app.get '/admin/data' do
      @products = ProductDAO.all
      @license_types = LicenseTypeDAO.all
      @roles = RoleDAO.all
      @users = UserDAO.all
      @devices = DeviceDAO.all
      @licenses = LicenseDAO.all
      @assignments = LicenseAssignmentDAO.all
      @logs = AssignmentLogDAO.all
      @security_logs = SecurityLogDAO.all

      erb :'admin/data_view/index', layout: :'layouts/application'
    end

    app.get '/admin/settings' do
      require_role('Admin')
      @title = 'SMTP Configuration Licentra'
      @smtp_settings = AppConfigDAO.get_smtp_settings
      erb :'admin/settings/index', layout: :'layouts/application'
    end

    app.post '/admin/settings' do
      require_role('Admin')

      settings_from_form = {
        server: params[:smtp_server]&.strip,
        port: params[:smtp_port]&.strip.to_i,
        security: params[:smtp_security]&.strip,
        username: params[:smtp_username]&.strip,
        smtp_password_from_form: params[:smtp_password]
      }

      if settings_from_form.slice(:server, :port, :security, :username).values.any?(&:nil?) || \
         settings_from_form.slice(:server, :security, :username).values.any?(&:empty?) || \
         settings_from_form[:port].zero?
        flash[:error] = 'Server, Port, Security, and Username are required.'
        redirect '/admin/settings'
        return
      end

      if AppConfigDAO.save_smtp_settings(settings_from_form)
        flash[:success] = 'SMTP settings saved successfully.'
      else
        flash[:error] = 'Failed to save SMTP settings. Please check logs.'
      end
      redirect '/admin/settings'
    end

    app.post '/admin/settings/test_smtp' do
      require_role('Admin')

      recipient_email = params[:test_email_recipient]&.strip

      if recipient_email.nil? || recipient_email.empty? || !recipient_email.match?(URI::MailTo::EMAIL_REGEXP)
        flash[:error] = 'Invalid recipient email address provided for the test.'
        redirect '/admin/settings'
      end

      begin
        puts "Attempting to send test email via EmailService to: #{recipient_email}"
        MailService.send_test_email(recipient_email)
        flash[:success] =
          "Test email successfully sent to #{recipient_email}. Please check the inbox (and spam folder)."
      rescue MailService::ConfigurationError => e
        # Dieser Fehler kommt, wenn SMTP nicht konfiguriert ist oder die Konfig nicht geladen/entschlüsselt werden konnte
        error_message = "SMTP Configuration Error: #{e.message}. Please verify your SMTP settings."
        puts "ERROR in /admin/settings/test_smtp: #{error_message}"
        flash[:error] = error_message
      rescue MailService::SendError => e
        # Dieser Fehler kommt bei SMTP-Problemen während des Versands
        error_message = "Failed to send test email: #{e.message}"
        puts "ERROR in /admin/settings/test_smtp: #{error_message}"
        flash[:error] = error_message
      rescue StandardError => e # Alle anderen unerwarteten Fehler
        error_message = "An unexpected error occurred: #{e.message}"
        puts "ERROR in /admin/settings/test_smtp (Unexpected): #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        flash[:error] = error_message
      end

      redirect '/admin/settings'
    end
  end
end
