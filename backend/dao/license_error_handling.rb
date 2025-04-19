require_relative 'errors'

module LicenseErrorHandling

  def handle_validation_error(license, context)
    log_validation_failed(license, context)
    raise ValidationError.new("Validation failed while #{context}", license.errors, license)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise RecordNotFound, "License with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise RecordNotFound, "License not found for criteria: #{criteria.inspect}"
  end

end
