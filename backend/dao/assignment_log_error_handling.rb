require_relative 'errors'

module LicenseAssignmentErrorHandling

  def handle_validation_error(assignment, context)
    log_validation_failed(assignment, context)
    raise ValidationError.new("Validation failed while #{context}", assignment.errors, assignment)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise RecordNotFound, "License Assignment with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise RecordNotFound, "License Assignment not found for criteria: #{criteria.inspect}"
  end

end
