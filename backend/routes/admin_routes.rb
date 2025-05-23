# frozen_string_literal: true

require_relative '../services/license_service'
require_relative '../dao/user_dao'

# Module for routes within admin context
module AdminRoutes
  def self.registered(app) # rubocop:disable Metrics/MethodLength
    app.get '/data' do
      require_role('Admin')
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

    app.get '/user_management' do
      require_role('Admin')
      @users = UserDAO.all
      @roles = RoleDAO.all
      erb :'admin/user_management/index', layout: :'layouts/application'
    end

    app.post '/user_management' do
      require_role('Admin')

      begin
        user_data = {
          username: params[:username],
          email: params[:email],
          first_name: params[:first_name],
          last_name: params[:last_name],
          is_active: true
        }

        user = UserDAO.create(user_data)

        if params[:password] && !params[:password].empty?
          UserCredentialDAO.create({
                                     user_id: user.user_id,
                                     password: params[:password]
                                   })
        else
          status 422
          flash[:error] = "Password is required to create a new user."
          return
        end

        if params[:roles].is_a?(Array)
          params[:roles].each do |role_id|
            UserRoleDAO.create(user.user_id, role_id.to_i)
          end
        end

        flash[:success] = "User '#{user.username}' successfully created."
        status 201

      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'Role not found.'
      rescue DAO::ValidationError => e
        status 422
        dao_validation_format_creation_error(e)
      rescue StandardError => e
        logger.error "Error creating user: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "An unexpected error occurred while creating the user: #{e.message}"
      end
    end


    app.put '/user_management/:user_id' do
      require_role('Admin')
      user_id = params[:user_id].to_i

      begin
        user_to_update = UserDAO.find!(user_id) # Kann DAO::RecordNotFound werfen
        update_data = params.slice(:username, :email, :first_name, :last_name).compact

        unless update_data.empty?
          UserDAO.update(user_id, update_data)
        end

        if params[:password] && !params[:password].empty?
          UserCredentialDAO.update_password(user_to_update.user_id, params[:password])
        end

        if params.key?(:roles)
          new_role_ids = params[:roles].is_a?(Array) ? params[:roles] : []
          UserRoleDAO.set_user_roles(user_to_update.user_id, new_role_ids)
        end

        flash[:success] = "User '#{user_to_update.username}' was successfully updated."
        status 200

      rescue DAO::RecordNotFound => e
        status 404
        flash[:error] = e.message
      rescue DAO::ValidationError => e
        status 422
        dao_validation_format_update_error(e)
      rescue DAO::AdminProtectionError => e
        status 403
        dao_admin_protection_error(e)
      rescue StandardError => e
        logger.error "Unexpected error updating user #{user_id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "An unexpected error occurred. Please try again or contact support."
      end
    end




    app.delete '/user_management/:user_id' do
      require_role('Admin')
      user_id = params[:user_id]

      begin
        if UserRoleDAO.is_user_admin?(user_id) && UserRoleDAO.count_admins <= 1
          status 403
          flash[:error] = "Admin protection: Cannot delete the last admin user from the system"
          return
        elsif LicenseAssignmentDAO.count_by_user(user_id) > 0
          status 422
          flash[:error] = "User protection: Cannot delete users with license assignments, delete those assignments first"
          return
        end

        UserDAO.delete(user_id)

        flash[:success] = 'User successfully deleted'
        status 200
      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'User not found.'
      rescue DAO::AdminProtectionError => e
        status 403
        flash[:error] = e.message
      rescue StandardError => e
        logger.error "Error deleting user: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error deleting user: #{e.message}"
      end
    end


    app.get '/user_management/:user_id/assignments' do
      require_role('Admin')
      user_id = params[:user_id]

      begin
        @user = UserDAO.find!(user_id)
        @assignments = LicenseAssignmentDAO.find_by_user(user_id)
        erb :'admin/user_management/assignments', layout: :'layouts/application'
      rescue DAO::RecordNotFound
        halt 404, 'User not found'
      end
    end

    app.put '/user_management/:user_id/assignments/:assignment_id/toggle_status' do
      require_role('Admin')
      assignment_id = params[:assignment_id].to_i
      activate = params[:is_active] == 'true'

      admin_user = current_user

      begin
        if activate
          LicenseService.activate_license_for_user(assignment_id, admin_user)
          flash[:success] = 'License assignment successfully activated'
        else
          LicenseService.deactivate_license_for_user(assignment_id, admin_user)
          flash[:success] = 'License assignment successfully deactivated'
        end
        status 200
      rescue LicenseService::ServiceError => e
        status_code = case e
                      when LicenseService::NotFoundError then 404
                      when LicenseService::NotAuthorizedError then 403
                      when LicenseService::NotAvailableError, LicenseService::AlreadyAssignedError then 409
                      else 400
                      end
        status status_code
        flash[:error] = e.message
      rescue StandardError => e
        logger.error "Error changing assignment status: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = 'An unexpected error occurred while changing assignment status.'
      end
    end

    app.get '/user_management/:user_id/available_licenses' do
      require_role('Admin')
      user_id = params[:user_id].to_i

      begin
        @user = UserDAO.find!(user_id)

        all_available_licenses = LicenseDAO.find_available_for_assignment
        user_assigned_license_ids = LicenseAssignmentDAO.find_by_user(user_id).map(&:license_id)

        @available_licenses_for_user = all_available_licenses.reject do |license|
          user_assigned_license_ids.include?(license.license_id)
        end

        content_type :json
        @available_licenses_for_user.map do |l|
          {
            license_id: l.license_id,
            product_name: l.product&.product_name || 'N/A',
            license_name: l&.license_name,
            license_key: l&.license_key,
            available_seats: l.available_seats
          }
        end.to_json
      rescue DAO::RecordNotFound
        status 404
        content_type :json
        { error: 'User not found' }.to_json
      rescue StandardError => e
        logger.error "Error fetching available licenses for user #{user_id}: #{e.message}"
        status 500
        content_type :json
        { error: 'Could not retrieve available licenses.' }.to_json
      end
    end

    app.post '/user_management/:user_id/assignments' do
      require_role('Admin')
      target_user_id = params[:user_id].to_i
      license_id = params[:license_id].to_i
      admin_user = current_user

      begin
        LicenseService.approve_assignment_for_user(license_id, target_user_id, admin_user)
        flash[:success] = 'License assignment successfully created (inactive)'
        status 200
      rescue LicenseService::ServiceError => e
        status_code = case e
                      when LicenseService::NotFoundError then 404
                      when LicenseService::NotAuthorizedError then 403
                      when LicenseService::AlreadyAssignedError then 409
                      else 400
                      end
        status status_code
        flash[:error] = e.message
      rescue StandardError => e
        logger.error "Error creating license assignment: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = 'An unexpected error occurred while creating the assignment.'
      end
    end

    app.delete '/user_management/:user_id/assignments/:assignment_id' do
      require_role('Admin')
      assignment_id = params[:assignment_id].to_i
      admin_user = current_user

      begin
        LicenseService.cancel_assignment_as_admin(assignment_id, admin_user)
        flash[:success] = 'License assignment successfully deleted'
        status 200
      rescue LicenseService::ServiceError => e
        status_code = case e
                      when LicenseService::NotFoundError then 404
                      when LicenseService::NotAuthorizedError then 403
                      else 400
                      end
        status status_code
        flash[:error] = e.message
      rescue StandardError => e
        logger.error "Error deleting license assignment: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = 'An unexpected error occurred while deleting the assignment.'
      end
    end

    app.get '/product_management' do
      require_role('Admin')
      @products = ProductDAO.all
      erb :'admin/product_management/index', layout: :'layouts/application'
    end

    app.post '/product_management' do
      require_role('Admin')
      product_name = params[:product_name]

      begin
        ProductDAO.create(product_name: product_name)
        flash[:success] = 'Product successfully created'
        status 200
      rescue DAO::ValidationError => e
        status 422
        flash[:error] = e.errors.full_messages.join(', ')
      rescue StandardError => e
        logger.error "Error creating product: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error creating product: #{e.message}"
      end
    end

    app.put '/product_management/:id' do
      require_role('Admin')
      product_id = params[:id]
      product_name = params[:product_name]

      begin
        ProductDAO.update(product_id, product_name: product_name)
        status 200
        flash[:success] = 'Product updated successfully'
      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'Product not found.'
      rescue DAO::ValidationError => e
        status 422
        flash[:error] = e.errors.full_messages.join(', ')
      rescue StandardError => e
        logger.error "Error updating product: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error updating product: #{e.message}"
      end
    end

    app.delete '/product_management/:id' do
      require_role('Admin')
      product_id = params[:id]

      if LicenseDAO.count_by_product(product_id) > 0
        status 422
        flash[:error] = "Cannot delete products with licenses, delete those licenses first"
        return
      end

      begin
        ProductDAO.delete(product_id)
        status 200
        flash[:success] = 'Product deleted successfully'
      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'Product not found.'
      rescue DAO::ConstraintViolationError
        status 409
        flash[:error] = 'Cannot delete product, it is still in use.'
      rescue StandardError => e
        logger.error "Error deleting product: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error deleting product: #{e.message}"
      end
    end

    app.get '/license_management' do
      require_role('Admin')
      @products = ProductDAO.all
      @licenses = LicenseDAO.all
      @license_types = LicenseTypeDAO.all
      erb :'admin/license_management/index', layout: :'layouts/application'
    end

    app.post '/license_management' do
      require_role('Admin')
      license_data = params.slice(
        :product_id, :license_type_id, :license_key, :license_name,
        :seat_count, :purchase_date, :expire_date, :cost,
        :currency, :vendor, :notes, :status
      ).transform_values { |v| v.is_a?(String) && v.empty? ? nil : v }

      begin
        LicenseDAO.create(license_data)
        status 200
        flash[:success] = 'License successfully created'
      rescue DAO::ValidationError => e
        status 422
        flash[:error] = e.errors.full_messages.join(', ')
      rescue StandardError => e
        logger.error "Error creating license: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error creating license: #{e.message}"
      end
    end

    app.put '/license_management/:id' do
      require_role('Admin')
      license_id = params[:id]
      license_data = params.slice(
        :product_id, :license_type_id, :license_key, :license_name,
        :seat_count, :purchase_date, :expire_date, :cost,
        :currency, :vendor, :notes, :status
      ).transform_values { |v| v.is_a?(String) && v.empty? ? nil : v }

      begin
        LicenseDAO.update(license_id, license_data)
        status 200
        flash[:success] = 'License successfully updated'
      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'License not found.'
      rescue DAO::ValidationError => e
        status 422
        flash[:error] = e.errors.full_messages.join(', ')
      rescue StandardError => e
        logger.error "Error updating license: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error updating license: #{e.message}"
      end
    end

    app.delete '/license_management/:id' do
      require_role('Admin')
      license_id = params[:id]

      if LicenseAssignmentDAO.count_by_license(license_id) > 0
        status 422
        flash[:error] = "Cannot delete licenses with assignments, delete those assignments first"
        return
      end

      begin
        LicenseDAO.delete(license_id)
        status 200
        flash[:success] = 'License successfully deleted'
      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'License not found.'
      rescue DAO::ConstraintViolationError
        status 409
        flash[:error] = 'Cannot delete license, it has active assignments.'
      rescue StandardError => e
        logger.error "Error deleting license: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error deleting license: #{e.message}"
      end
    end

    app.get '/admin/settings' do
      require_role('Admin')
      @title = "SMTP Configuration Licentra"
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
         settings_from_form[:port] == 0
        flash[:error] = "Server, Port, Security, and Username are required."
        redirect '/admin/settings'
        return
      end


      if AppConfigDAO.save_smtp_settings(settings_from_form)
        flash[:success] = "SMTP settings saved successfully."
      else
        flash[:error] = "Failed to save SMTP settings. Please check logs."
      end
      redirect '/admin/settings'

    end

    app.post '/admin/settings/test_smtp' do
      require_role('Admin')

      recipient_email = params[:test_email_recipient]&.strip

      if recipient_email.nil? || recipient_email.empty? || !recipient_email.match?(URI::MailTo::EMAIL_REGEXP)
        flash[:error] = "Invalid recipient email address provided for the test."
        redirect '/admin/settings'
      end

      begin
        puts "Attempting to send test email via EmailService to: #{recipient_email}"
        MailService.send_test_email(recipient_email)
        flash[:success] = "Test email successfully sent to #{recipient_email}. Please check the inbox (and spam folder)."
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
      rescue => e # Alle anderen unerwarteten Fehler
        error_message = "An unexpected error occurred: #{e.message}"
        puts "ERROR in /admin/settings/test_smtp (Unexpected): #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        flash[:error] = error_message
      end

      redirect '/admin/settings'
    end
  end
end
