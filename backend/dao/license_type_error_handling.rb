require_relative 'errors'

module LicenseTypeErrorHandling

  def handle_validation_error(license_type, context)
    log_validation_failed(license_type, context)
    raise ValidationError.new("Validation failed while #{context}", license_type.errors, license_type)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise RecordNotFound, "License Type with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise RecordNotFound, "License Type not found for criteria: #{criteria.inspect}"
  end

  def handle_record_not_found_by_name(name)
    log_record_not_found_by_name(name)
    raise RecordNotFound, "License Type not found with name: '#{name}'"
  end
  
end
