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

      # Neues Produkt anlegen
      begin
        product = Product.new(product_name: product_name)
        if product.valid?
          product.save_changes
          status 201
          body 'Product created successfully'
        else
          status 422
          body product.errors.full_messages.join(', ')
        end
      rescue => e
        status 500
        body "Error creating product: #{e.message}"
      end
    end

    app.get '/license_management' do
      require_role('Admin')
      erb :license_management
    end
  end
end
