require_relative 'errors'

module UserErrorHandling

  def handle_validation_error(user, context)
    log_validation_failed(user, context)
    raise ValidationError.new("Validation failed while #{context}", user.errors, user)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise RecordNotFound, "User with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise RecordNotFound, "User not found for criteria: #{criteria.inspect}"
  end

  def handle_record_not_found_by_username(username)
    log_record_not_found_by_username(username)
    raise RecordNotFound, "User not found with username: '#{username}'"
  end

  def handle_record_not_found_by_email(email)
    log_record_not_found_by_email(email)
    raise RecordNotFound, "User not found with email: '#{email}'"
  end

end
