# frozen_string_literal: true

# Logging functionality specific to LicenseAssignment operations
module LicenseAssignmentLogging
  def log_created(assignment)
    log_info("License Assignment record created: ID #{assignment.pk}, License ID #{assignment.license_id}, #{assignment.assignee_type} ID #{assignment.assignee_id}, Active: #{assignment.is_active}")
  end

  def log_found(assignment)
    log_info("License Assignment found: ID #{assignment.pk}")
  end

  def log_found_by_criteria(criteria, assignment)
    log_info("License Assignment found by #{criteria.inspect}: ID #{assignment.pk}")
  end

  def log_fetched(count)
    log_info("Fetched #{count} license assignments")
  end

  def log_fetched_with_criteria(count, criteria)
    log_info("Fetched #{count} license assignments with criteria: #{criteria.inspect}")
  end

  def log_updated(assignment)
    log_info("License Assignment record updated: ID #{assignment.pk}")
    details = begin
      assignment.previous_changes.map do |col, vals|
        "#{col}: #{vals[0]} -> #{vals[1]}"
      end.join(', ')
    rescue StandardError
      'Changes unavailable'
    end
    log_info("License Assignment record updated: ID #{assignment.pk}. Changes: #{details}")
  end

  def log_deleted(assignment)
    log_info("License Assignment deleted: ID #{assignment.pk}, License ID #{assignment.license_id}, #{assignment.assignee_type} ID #{assignment.assignee_id}")
  end

  def log_validation_failed(assignment, context)
    log_warn("Validation failed while #{context} assignment (ID: #{assignment.pk || 'new'}, License: #{assignment.license_id}, Assignee: #{assignment.assignee_type} #{assignment.assignee_id}): #{assignment.errors.inspect}")
  end

  def log_record_not_found(id)
    log_warn("License Assignment with ID #{id} not found")
  end

  def log_record_not_found_by_criteria(criteria)
    log_warn("License Assignment not found for criteria: #{criteria.inspect}")
  end

  def log_assignments_for_license_fetched(license_id, count)
    log_info("Fetched #{count} assignments for License ID #{license_id}")
  end

  def log_assignments_for_user_fetched(user_id, count)
    log_info("Fetched #{count} assignments for User ID #{user_id}")
  end

  def log_assignments_for_device_fetched(device_id, count)
    log_info("Fetched #{count} assignments for Device ID #{device_id}")
  end

  def log_assignment_activated(assignment)
    log_info("License Assignment activated: ID #{assignment.pk}")
  end

  def log_assignment_deactivated(assignment)
    log_info("License Assignment deactivated: ID #{assignment.pk}")
  end
end
