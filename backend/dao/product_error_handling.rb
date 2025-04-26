# frozen_string_literal: true

require_relative 'errors'

# Error handling specific to Product operations
module ProductErrorHandling
  include DAO

  def handle_validation_error(product, context)
    log_validation_failed(product, context)
    raise ValidationError.new("Validation failed while #{context}", product.errors, product)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise RecordNotFound, "Product with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise RecordNotFound, "Product not found for criteria: #{criteria.inspect}"
  end

  def handle_record_not_found_by_name(name)
    log_record_not_found_by_name(name)
    raise RecordNotFound, "Product not found with name: '#{name}'"
  end
end
