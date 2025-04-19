require_relative 'errors'

module UserRoleErrorHandling

  def handle_validation_error(assignment, context)
    raise ValidationError.new("Validation failed while #{context}", assignment.errors, assignment)
  end

  def handle_record_not_found(user_id, role_id)
    log_assignment_not_found(user_id, role_id)
    raise RecordNotFound, "UserRole assignment not found for User ID #{user_id} and Role ID #{role_id}"
  end

  def handle_record_not_found_by_criteria(criteria)
     raise RecordNotFound, "UserRole assignment not found for criteria: #{criteria.inspect}"
  end
end
