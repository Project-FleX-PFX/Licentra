# frozen_string_literal: true

# Helper for error handling in admin routes.
module AdminRoutesErrorHelpers
  def handle_product_service_errors(product_id: nil)
    yield
  rescue ProductService::ProductManagementError, ProductService::NotFoundError, ProductService::NotAuthorizedError => e
    flash[:error] = e.message
  rescue StandardError => e
    log_message = "Unexpected error"
    log_message += " deleting product (ID: #{product_id})" if product_id
    log_message += ": #{e.message}\n#{e.backtrace.join("\n")}"
    logger.error log_message
    flash[:error] = 'An unexpected application error occurred.'
  end

  def handle_license_service_errors(license_id: nil)
    yield
  rescue LicenseService::LicenseManagementError, LicenseService::NotFoundError, LicenseService::NotAuthorizedError => e
    flash[:error] = e.message
  rescue StandardError => e
    log_message = "Unexpected error"
    log_message += " with license (ID: #{license_id})" if license_id
    log_message += ": #{e.message}\n#{e.backtrace.join("\n")}"
    logger.error log_message
    flash[:error] = 'An unexpected application error occurred.'
  end

  def handle_user_service_errors(user_id: nil)
    yield
  rescue UserService::UserManagementError, UserService::NotFoundError, UserService::NotAuthorizedError, UserService::AdminProtectionError => e
    flash[:error] = e.message
  rescue StandardError => e
    log_message = "Unexpected error"
    log_message += " with user (ID: #{user_id})" if user_id
    log_message += ": #{e.message}\n#{e.backtrace.join("\n")}"
    logger.error log_message
    flash[:error] = 'An unexpected application error occurred.'
  end
end