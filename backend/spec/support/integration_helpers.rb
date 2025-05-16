# frozen_string_literal: true

require 'fabrication'

# Contains some helper methods that help with integration testing
module IntegrationHelpers
  # --- User & Role Setup ---

  def setup_roles
    @admin_role ||= Fabricate(:role, role_name: 'Admin')
    @user_role  ||= Fabricate(:role, role_name: 'User')
  end

  def create_admin_user(username: 'admin_test_user', email: 'admin_test@example.com', password: DEFAULT_PASSWORD)
    setup_roles
    user = Fabricate(:user,
                     username: username,
                     email: email,
                     first_name: 'Admin',
                     last_name: 'User',
                     is_active: true)
    Fabricate(:user_credential, user: user, password: password)
    user.add_role(@admin_role)
    user.add_role(@user_role)
    user.refresh
    user
  end

  def create_regular_user(username: 'regular_test_user', email: 'regular_test@example.com', password: DEFAULT_PASSWORD)
    setup_roles
    user = Fabricate(:user,
                     username: username,
                     email: email,
                     first_name: 'Regular',
                     last_name: 'User',
                     is_active: true)
    Fabricate(:user_credential, user: user, password: password)
    user.add_role(@user_role)
    user.refresh
    user
  end

  # --- Authentication Helpers ---
  def login_as(user, password = DEFAULT_PASSWORD)
    post '/login', { email: user.email, password: password }
    follow_redirect! while last_response.redirect?
    expect(session[:user_id]).to eq(user.user_id)
  end

  def logout
    post '/logout'
    follow_redirect! while last_response.redirect?
    expect(session[:user_id]).to be_nil
  end

  # --- General Rack::Test Helpers ---
  def response_body
    last_response.body
  end

  def response_status
    last_response.status
  end

  # --- Domain Specific Helpers ---
  def create_product_via_ui(name, description = 'Test Description')
    post '/product_management', { product_name: name, product_description: description }
  end

  def create_license_type_via_dao(name: 'Test License Type')
    LicenseTypeDAO.create(type_name: name)
  end

  def create_product_via_dao(name: 'Test Product')
    ProductDAO.create(product_name: name)
  end

  def create_license_via_dao(product:, license_type:, key: "TESTKEY-#{SecureRandom.hex(4)}", name: 'Test License',
                             seats: 5, expire_date: nil)
    LicenseDAO.create(
      product_id: product.product_id,
      license_type_id: license_type.license_type_id,
      license_key: key,
      license_name: name,
      seat_count: seats,
      expire_date: expire_date
    )
  end
end
