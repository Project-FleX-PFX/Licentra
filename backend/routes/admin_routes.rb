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
      erb :user_management
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
        status 200
        body 'Product successfully created'
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        body error_messages
      rescue => e
        status 500
        body "Error updating product: #{e.message}"
      end
    end

    app.put '/product_management/:id' do
      require_role('Admin')
      product_id = params[:id]
      product_name = params[:product_name]

      begin
        ProductDAO.update(product_id, product_name: product_name)
        status 200
        body 'Product updated successfully'
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        body error_messages
      rescue => e
        status 500
        body "Error updating product: #{e.message}"
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
        body 'License successfully created'
      rescue DAO::ValidationError => e
        status 422
        error_messages = e.respond_to?(:errors) ? e.errors.full_messages.join(',') : e.message
        body error_messages
      rescue => e
        status 500
        body "Error creating license: #{e.message}"
      end
    end
  end
end
