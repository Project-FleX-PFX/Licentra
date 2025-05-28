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
end