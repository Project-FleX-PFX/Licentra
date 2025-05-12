# frozen_string_literal: true

require_relative 'errors'

# Error handling specific to LicenseType operations
module LicenseTypeErrorHandling
  include DAO

  def handle_validation_error(license_type, context)
    log_validation_failed(license_type, context)
    raise DAO::ValidationError.new("Validation failed while #{context}", license_type.errors, license_type)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise DAO::RecordNotFound, "License Type with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise DAO::RecordNotFound, "License Type not found for criteria: #{criteria.inspect}"
  end

  def handle_record_not_found_by_name(name)
    log_record_not_found_by_name(name)
    raise DAO::RecordNotFound, "License Type not found with name: '#{name}'"
  end
end
