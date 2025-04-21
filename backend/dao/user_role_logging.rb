# frozen_string_literal: true

# Logging functionality specific to UserRole operations
module UserRoleLogging
  def log_assignment_created(user_id, role_id)
    log_info("UserRole assignment created: User ID #{user_id} <-> Role ID #{role_id}")
  end

  def log_assignment_object_found(assignment)
    log_info("UserRole assignment object found: #{assignment.inspect}")
  end

  def log_assignment_found(user_id, role_id)
    log_info("UserRole assignment found for User ID #{user_id} and Role ID #{role_id}")
  end

  def log_assignment_not_found(user_id, role_id)
    log_warn("UserRole assignment not found for User ID #{user_id} and Role ID #{role_id}")
  end

  def log_assignments_for_user_fetched(user_id, count)
    log_info("Fetched #{count} role assignments for User ID #{user_id}")
  end

  def log_assignments_for_role_fetched(role_id, count)
    log_info("Fetched #{count} user assignments for Role ID #{role_id}")
  end

  def log_assignment_deleted(user_id, role_id)
    log_info("UserRole assignment deleted: User ID #{user_id} <-> Role ID #{role_id}")
  end

  def log_assignments_deleted_for_user(user_id, count)
    log_info("Deleted #{count} role assignments for User ID #{user_id}")
  end

  def log_assignments_deleted_for_role(role_id, count)
    log_info("Deleted #{count} user assignments for Role ID #{role_id}")
  end

  def log_validation_failed(assignment, context)
    log_warn("Validation failed while #{context} assignment: #{assignment.errors.inspect}")
  end
end
