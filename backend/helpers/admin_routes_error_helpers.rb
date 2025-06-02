# frozen_string_literal: true

# Helper for error handling in admin routes.
module AdminRoutesErrorHelpers
  def handle_product_service_errors(product_id: nil)
    yield
  rescue ProductService::ProductManagementError => e
    flash[:error] = e.message
    halt 422, { error: e.message }.to_json
  rescue ProductService::NotFoundError => e
    flash[:error] = e.message
    halt 404, { error: e.message }.to_json
  rescue ProductService::NotAuthorizedError => e
    flash[:error] = e.message
    halt 403, { error: e.message }.to_json
  rescue StandardError => e
    log_message = 'Unexpected error'
    log_message += " deleting product (ID: #{product_id})" if product_id
    log_message += ": #{e.message}\n#{e.backtrace.join("\n")}"
    logger.error log_message
    flash[:error] = 'An unexpected server error occurred.'
    halt 500, { error: 'An unexpected server error occurred.' }.to_json
  end

  def handle_license_service_errors(license_id: nil)
    yield
  rescue LicenseService::LicenseManagementError => e
    flash[:error] = e.message
    halt 422, { error: e.message }.to_json
  rescue LicenseService::NotFoundError => e
    flash[:error] = e.message
    halt 404, { error: e.message }.to_json
  rescue LicenseService::NotAuthorizedError => e
    flash[:error] = e.message
    halt 403, { error: e.message }.to_json
  rescue DAO::ValidationError => e
    dao_validation_format_creation_error(e)
    halt 403, { error: e.message }.to_json
  rescue StandardError => e
    log_message = 'Unexpected error'
    log_message += " with license (ID: #{license_id})" if license_id
    log_message += ": #{e.message}\n#{e.backtrace.join("\n")}"
    logger.error log_message
    flash[:error] = 'An unexpected server error occurred.'
    halt 500, { error: 'An unexpected server error occurred.' }.to_json
  end

  def handle_user_service_errors(user_id: nil)
    yield
  rescue DAO::RecordNotFound
    flash[:error] = 'The requested resource was not found.'
    halt 404, { error: 'Resource not found.' }.to_json
  rescue DAO::ValidationError => e
    dao_validation_format_creation_error(e)
    halt 403, { error: e.message }.to_json
  rescue UserService::NotFoundError => e
    flash[:error] = e.message
    halt 404, { error: e.message }.to_json
  rescue UserService::UserManagementError, UserService::AdminProtectionError => e
    flash[:error] = e.message
    halt 422, { error: e.message }.to_json
  rescue UserService::NotAuthorizedError => e
    flash[:error] = e.message
    halt 403, { error: e.message }.to_json
  rescue Sequel::ValidationFailed => e
    full_message = "Validation failed: #{e.errors.full_messages.join(', ')}"
    flash[:error] = full_message
    halt 422, { error: full_message }.to_json
  rescue StandardError => e
    log_message = 'Unexpected error'
    log_message += " with user (ID: #{user_id})" if user_id
    log_message += ": #{e.message}\n#{e.backtrace.join("\n")}"
    logger.error log_message
    flash[:error] = 'An unexpected server error occurred.'
    halt 500, { error: 'An unexpected server error occurred.' }.to_json
  end

  def handle_license_assignment_service_errors(user_id: nil, assignment_id: nil, license_id: nil)
    yield
  rescue LicenseService::NotFoundError => e
    flash[:error] = e.message
    halt 404, { error: e.message }.to_json
  rescue LicenseService::NotAvailableError => e
    flash[:error] = e.message
    halt 409, { error: e.message }.to_json
  rescue LicenseService::AlreadyAssignedError => e
    flash[:error] = e.message
    halt 409, { error: e.message }.to_json
  rescue LicenseService::NotAuthorizedError => e
    flash[:error] = e.message
    halt 403, { error: e.message }.to_json
  rescue LicenseService::LicenseManagementError => e
    flash[:error] = e.message
    halt 400, { error: e.message }.to_json
  rescue LicenseService::ServiceError => e
    flash[:error] = e.message
    halt 400, { error: e.message }.to_json
  rescue DAO::RecordNotFound
    flash[:error] = 'The requested resource was not found.'
    halt 404, { error: 'Resource not found.' }.to_json
  rescue DAO::ValidationError => e
    dao_validation_format_creation_error(e)
    halt 403, { error: e.message }.to_json
  rescue StandardError => e
    log_message = 'Unexpected error'
    log_message += " with user (ID: #{user_id})" if user_id
    log_message += " assignment (ID: #{assignment_id})" if assignment_id
    log_message += " for license (ID: #{license_id})" if license_id
    log_message += ": #{e.message}\n#{e.backtrace.join("\n")}"
    logger.error log_message
    flash[:error] = 'An unexpected server error occurred.'
    halt 500, { error: 'An unexpected server error occurred.' }.to_json
  end
end
