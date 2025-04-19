require_relative 'errors'

module AssignmentLogErrorHandling
  def handle_validation_error(log, context)
    log_validation_failed(log, context)
    raise ValidationError.new("Validation failed while #{context}", log.errors, log)
  end

  def handle_record_not_found(id)
    log_log_not_found(id)
    raise RecordNotFound, "Assignment Log with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_log_not_found_by_criteria(criteria)
    raise RecordNotFound, "Assignment Log not found for criteria: #{criteria.inspect}"
  end
end
