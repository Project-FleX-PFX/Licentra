# frozen_string_literal: true

# Module for routes within admin context
module AdminRoutes
  def self.registered(app)
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

      erb :data, layout: false
    end

    app.get '/user_management' do
      require_role('Admin')
      @users = UserDAO.all
      @roles = RoleDAO.all
      erb :user_management
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
        # Benutzer erstellen
        user = User.new(user_data)
        user.save_changes

        # Rollen zuweisen
        if params[:roles] && params[:roles].is_a?(Array)
          params[:roles].each do |role_id|
            role = RoleDAO.find(role_id)
            user.add_role(role) if role
          end
        end

        flash[:success] = 'User successfully created'
        status 200
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
        status 500
        flash[:error] = "Error creating user: #{e.message}"
      end
    end

    app.put '/user_management/:id' do
      require_role('Admin')
      user_id = params[:id]

      begin
        user = UserDAO.find(user_id)
        return status 404 unless user

        # Basisinformationen aktualisieren
        user.username = params[:username] if params[:username]
        user.email = params[:email] if params[:email]
        user.first_name = params[:first_name] if params[:first_name]
        user.last_name = params[:last_name] if params[:last_name]

        # Passwort aktualisieren, wenn angegeben
        if params[:password] && !params[:password].empty?
          user.credential.password = params[:password]
          user.credential.save_changes
        end

        # Änderungen speichern
        user.save_changes

        # Rollen aktualisieren
        if params[:roles].is_a?(Array)
          # Alle bestehenden Rollen entfernen
          user.remove_all_roles

          # Neue Rollen zuweisen
          params[:roles].each do |role_id|
            role = RoleDAO.find(role_id)
            user.add_role(role) if role
          end
        end

        flash[:success] = 'User successfully updated'
        status 200
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
        status 500
        flash[:error] = "Error updating user: #{e.message}"
      end
    end

    app.delete '/user_management/:id' do
      require_role('Admin')
      user_id = params[:id]

      begin
        user = UserDAO.find(user_id)
        return status 404 unless user

        # Benutzer löschen
        user.delete

        flash[:success] = 'User successfully deleted'
        status 200
      rescue StandardError => e
        status 500
        flash[:error] = "Error deleting user: #{e.message}"
      end
    end

    app.get '/user_management/:user_id/assignments' do
      require_role('Admin')
      user_id = params[:user_id]

      @user = UserDAO.find(user_id)
      halt 404, 'User not found' unless @user

      @assignments = LicenseAssignmentDAO.find_by_user(user_id)

      erb :user_management_assignments
    end

    app.put '/user_management/:id/assignments/:assignment_id/toggle_status' do
      require_role('Admin')
      user_id = params[:id]
      assignment_id = params[:assignment_id]
      is_active = params[:is_active] == 'true'

      begin
        # Finde die notwendigen Objekte für das Logging
        assignment = LicenseAssignmentDAO.find(assignment_id)
        halt 404, 'Assignment not found' unless assignment

        admin_user = current_user
        license = assignment.license

        # Aktivieren oder Deaktivieren mit der DAO-Methode
        if is_active
          LicenseAssignmentDAO.activate(assignment_id)
          action_type = 'ADMIN_ACTIVATED'
        else
          LicenseAssignmentDAO.deactivate(assignment_id)
          action_type = 'ADMIN_DEACTIVATED'
        end

        # Verwende die Logging-Methode aus dem Service
        details = "User '#{admin_user.username}' (ID: #{admin_user.user_id}) performed action '#{action_type}' " \
          "for license '#{LicenseService._license_display_name(license)}' (License ID: #{license.license_id}). " \
          "Assignment ID: #{assignment.assignment_id}."

        AssignmentLogDAO.create(
          assignment_id: assignment.assignment_id,
          action: action_type,
          details: details
        )

        flash[:success] =
          is_active ? 'License assignment successfully activated' : 'License assignment successfully deactivated'
        status 200
      rescue StandardError => e
        status 500
        flash[:error] = "Error changing assignment status: #{e.message}"
      end
    end

    # Route zum Abrufen verfügbarer Lizenzen für einen Benutzer
    app.get '/user_management/:user_id/available_licenses' do
      require_role('Admin')
      user_id = params[:user_id]

      @user = UserDAO.find(user_id)
      halt 404, 'User not found' unless @user

      # Alle verfügbaren Lizenzen finden
      all_available = LicenseDAO.find_available_for_assignment

      # Bereits zugewiesene Lizenzen für diesen Benutzer finden (unabhängig vom Status)
      user_assigned_license_ids = LicenseAssignmentDAO.find_by_user(user_id).map(&:license_id)

      # Nur Lizenzen zurückgeben, die dem Benutzer noch nicht zugewiesen wurden
      @available_licenses = all_available.reject do |license|
        user_assigned_license_ids.include?(license.license_id)
      end

      content_type :json
      @available_licenses.map do |l|
        {
          license_id: l.license_id,
          product_name: l.product.product_name,
          license_key: l.license_key,
          available_seats: l.available_seats
        }
      end.to_json
    end

    # Route zum Erstellen einer neuen Lizenzzuweisung
    app.post '/user_management/:user_id/assignments' do
      require_role('Admin')
      user_id = params[:user_id]
      license_id = params[:license_id]

      begin
        @user = UserDAO.find(user_id)
        halt 404, 'User not found' unless @user

        # Neue Zuweisung erstellen, aber auf inaktiv setzen
        assignment = LicenseAssignmentDAO.create({
                                                   license_id: license_id,
                                                   user_id: user_id,
                                                   assignment_date: Time.now,
                                                   is_active: false # Standardmäßig inaktiv
                                                 })

        # Logging
        license = assignment.license
        admin_user = current_user

        details = "User '#{admin_user.username}' (ID: #{admin_user.user_id}) performed action 'ADMIN_ASSIGNED' " \
          "for license '#{LicenseService._license_display_name(license)}' (License ID: #{license.license_id}). " \
          "Assignment ID: #{assignment.assignment_id}."

        AssignmentLogDAO.create(
          assignment_id: assignment.assignment_id,
          action: 'ADMIN_ASSIGNED',
          details: details
        )

        flash[:success] = 'License assignment successfully created (inactive)'
        status 200
      rescue StandardError => e
        status 500
        flash[:error] = "Error creating license assignment: #{e.message}"
      end
    end

    app.delete '/user_management/:user_id/assignments/:assignment_id' do
      require_role('Admin')
      user_id = params[:user_id]
      assignment_id = params[:assignment_id]

      begin
        # Zuweisung finden
        assignment = LicenseAssignmentDAO.find(assignment_id)
        halt 404, 'Assignment not found' unless assignment

        # Überprüfen, ob die Zuweisung inaktiv ist
        halt 400, 'Cannot delete active assignment' if assignment.is_active?

        # Logging
        admin_user = current_user
        license = assignment.license

        details = "User '#{admin_user.username}' (ID: #{admin_user.user_id}) performed action 'ADMIN_DELETED' " \
          "for license '#{LicenseService._license_display_name(license)}' (License ID: #{license.license_id}). " \
          "Assignment ID: #{assignment.assignment_id}."

        AssignmentLogDAO.create(
          assignment_id: assignment_id,
          action: 'ADMIN_DELETED',
          details: details
        )

        # Zuweisung löschen
        LicenseAssignmentDAO.delete(assignment_id)

        flash[:success] = 'License assignment successfully deleted'
        status 200
      rescue StandardError => e
        status 500
        flash[:error] = "Error deleting license assignment: #{e.message}"
      end
    end

    app.get '/product_management' do
      require_role('Admin')
      @products = ProductDAO.all
      erb :product_management
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
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
        status 500
        flash[:error] = "Error updating product: #{e.message}"
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
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
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
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_message.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
        status 500
        flash[:error] = "Error deleting product: #{e.message}"
      end
    end

    app.get '/license_management' do
      require_role('Admin')
      @products = ProductDAO.all
      @licenses = LicenseDAO.all
      @license_types = LicenseTypeDAO.all
      erb :license_management
    end

    app.post '/license_management' do
      require_role('Admin')
      license_data = {
        product_id: params[:product_id],
        license_type_id: params[:license_type_id],
        license_key: params[:license_key],
        license_name: params[:license_name],
        seat_count: params[:seat_count],
        purchase_date: params[:purchase_date],
        expire_date: params[:expire_date],
        cost: params[:cost],
        currency: params[:currency],
        vendor: params[:vendor],
        notes: params[:notes],
        status: params[:status]
      }

      begin
        LicenseDAO.create(license_data)
        status 200
        flash[:success] = 'License successfully created'
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
        status 500
        flash[:error] = "Error creating license: #{e.message}"
      end
    end

    app.put '/license_management/:id' do
      require_role('Admin')
      license_id = params[:id]
      license_data = {
        product_id: params[:product_id],
        license_type_id: params[:license_type_id],
        license_key: params[:license_key],
        license_name: params[:license_name],
        seat_count: params[:seat_count],
        purchase_date: params[:purchase_date],
        expire_date: params[:expire_date],
        cost: params[:cost],
        currency: params[:currency],
        vendor: params[:vendor],
        notes: params[:notes],
        status: params[:status]
      }

      begin
        LicenseDAO.update(license_id, license_data)
        status 200
        flash[:success] = 'License successfully updated'
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
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
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        flash[:error] = error_messages
      rescue StandardError => e
        status 500
        flash[:error] = "Error deleting license: #{e.message}"
      end
    end
  end
end
