require_relative 'errors'

module RoleErrorHandling

  def handle_validation_error(role, context)
    log_validation_failed(role, context)
    raise ValidationError.new("Validation failed while #{context}", role.errors, role)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise RecordNotFound, "Role with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise RecordNotFound, "Role not found for criteria: #{criteria.inspect}"
  end

  def handle_record_not_found_by_name(name)
    log_record_not_found_by_name(name)
    raise RecordNotFound, "Role not found with name: '#{name}'"
  end
  
end
