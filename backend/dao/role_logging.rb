# frozen_string_literal: true

# Logging functionality specific to Role operations
module RoleLogging
  def log_created(role)
    log_info("Role created: #{role.inspect}")
  end

  def log_found(role)
    log_info("Role found: #{role.inspect}")
  end

  def log_found_by_criteria(criteria, role)
    log_info("Role found by #{criteria.inspect}: #{role.inspect}")
  end

  def log_fetched(count)
    log_info("Fetched #{count} roles")
  end

  def log_fetched_with_criteria(count, criteria)
    log_info("Fetched #{count} roles with criteria: #{criteria.inspect}")
  end

  def log_updated(role)
    log_info("Role updated: #{role.inspect}")
  end

  def log_deleted(role)
    log_info("Role deleted: #{role.inspect}")
  end

  def log_validation_failed(role, context)
    log_warn("Validation failed while #{context} role: #{role.errors.inspect}")
  end

  def log_record_not_found(id)
    log_warn("Role with ID #{id} not found")
  end

  def log_record_not_found_by_criteria(criteria)
    log_warn("Role not found for criteria: #{criteria.inspect}")
  end

  def log_record_not_found_by_name(name)
    log_warn("Role not found with name: '#{name}'")
  end

  def log_role_found_by_name(name, role)
    log_info("Role found by name '#{name}': #{role.inspect}")
  end
end
