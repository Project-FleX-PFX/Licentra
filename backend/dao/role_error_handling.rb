# frozen_string_literal: true

require_relative 'errors'

# Error handling specific to Role operations
module RoleErrorHandling
  include DAO

  def handle_validation_error(role, context)
    log_validation_failed(role, context)
    raise DAO::ValidationError.new("Validation failed while #{context}", role.errors, role)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise DAO::RecordNotFound, "Role with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise DAO::RecordNotFound, "Role not found for criteria: #{criteria.inspect}"
  end

  def handle_record_not_found_by_name(name)
    log_record_not_found_by_name(name)
    raise DAO::RecordNotFound, "Role not found with name: '#{name}'"
  end
end
