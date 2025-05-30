# frozen_string_literal: true

require_relative 'errors'

# Error handling specific to LicenseAssignment operations
module LicenseAssignmentErrorHandling
  include DAO

  def handle_validation_error(assignment, context)
    log_validation_failed(assignment, context)
    raise DAO::ValidationError.new("Validation failed while #{context}", assignment.errors, assignment)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise DAO::RecordNotFound, "License Assignment with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise DAO::RecordNotFound, "License Assignment not found for criteria: #{criteria.inspect}"
  end
end
