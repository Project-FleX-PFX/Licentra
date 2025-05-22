# frozen_string_literal: true

require_relative 'errors'

# Error handling specific to UserRole operations
module UserRoleErrorHandling
  include DAO

  def handle_record_not_found(user_id, role_id)
    log_assignment_not_found(user_id, role_id)
    raise DAO::RecordNotFound, "UserRole assignment not found for User ID #{user_id} and Role ID #{role_id}"
  end

  def handle_validation_error(assignment, context)
    log_validation_failed(assignment, context)
    raise DAO::ValidationError.new("Validation failed while #{context}", assignment.errors, assignment)
  end

  def handle_record_not_found_by_criteria(criteria)
    log_assignment_not_found_by_criteria(criteria)
    raise DAO::RecordNotFound, "UserRole assignment not found for criteria: #{criteria.inspect}"
  end

  def handle_admin_protection(context)
    log_admin_protection(context)

    message = case context
              when /deleting assignment for user_id .+, role_id .+/
                "Cannot remove the admin role from the last administrator"
              when /deleting all assignments for user_id .+/
                "Cannot remove all roles from the last administrator"
              when /deleting all assignments for role_id .+/
                "Cannot remove the admin role from the system"
              else
                "This operation would leave the system without administrators"
              end

    raise DAO::AdminProtectionError, message
  end
end
