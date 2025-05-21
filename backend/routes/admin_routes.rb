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
      user_data = {
        username: params[:username],
        email: params[:email],
        first_name: params[:first_name],
        last_name: params[:last_name],
        is_active: true,
        credential_attributes: {
          password: params[:password]
        }
      }

      begin
        user = User.new(user_data)
        user.save_changes

        if params[:roles].is_a?(Array)
          params[:roles].each do |role_id|
            role = RoleDAO.find(role_id)
            user.add_role(role) if role
          end
        end

        flash[:success] = 'User successfully created'
        status 200
      rescue Sequel::ValidationFailed => e
        status 422
        flash[:error] = e.errors.full_messages.join(', ')
      rescue StandardError => e
        logger.error "Error creating user: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error creating user: #{e.message}"
      end
    end

    app.put '/user_management/:user_id' do
      require_role('Admin')
      user_id = params[:user_id]

      begin
        user = UserDAO.find!(user_id)

        update_data = params.slice(:username, :email, :first_name, :last_name).compact
        user.set(update_data) unless update_data.empty?

        if params[:password] && !params[:password].empty?
          user.credential.password = params[:password]
          user.credential.save_changes
        end

        user.save_changes

        if params[:roles].is_a?(Array)
          user.remove_all_roles
          params[:roles].each do |role_id|
            role = RoleDAO.find(role_id)
            user.add_role(role) if role
          end
        end

        flash[:success] = 'User successfully updated'
        status 200
      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'User not found.'
      rescue Sequel::ValidationFailed => e
        status 422
        flash[:error] = e.errors.full_messages.join(', ')
      rescue StandardError => e
        logger.error "Error updating user: #{e.message}\n#{e.backtrace.join("\n")}"
        status 500
        flash[:error] = "Error updating user: #{e.message}"
      end
    end

    app.delete '/user_management/:user_id' do
      require_role('Admin')
      user_id = params[:user_id]

      begin
        user = UserDAO.find!(user_id)
        user.delete

        flash[:success] = 'User successfully deleted'
        status 200
      rescue DAO::RecordNotFound
        status 404
        flash[:error] = 'User not found.'
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
  end
end
