# frozen_string_literal: true

# Logging module for the SecurityLogDAO operations.
module SecurityLogLogging
  # Logs the creation of a SecurityLog entry.
  def log_security_log_created(log)
    user_info = log.user_id ? "User ID #{log.user_id}" : 'No specific user'
    log_info("Security Log created: ID #{log.pk}, #{user_info}, Action: #{log.action}, Object: #{log.object}, Time: #{log.log_timestamp}")
  end

  # Logs when a SecurityLog entry is found.
  def log_security_log_found(log)
    log_info("Security Log found: ID #{log.pk}, Action: #{log.action}, Object: #{log.object}")
  end

  # Logs when a SecurityLog entry is not found by ID.
  def log_security_log_not_found(id)
    log_warn("Security Log with ID #{id} not found")
  end

  # Logs when a SecurityLog entry is found by criteria.
  def log_security_log_found_by_criteria(criteria, log)
    log_info("Security Log found by #{criteria.inspect}: ID #{log.pk}, Action: #{log.action}")
  end

  # Logs when a SecurityLog entry is not found by criteria.
  def log_security_log_not_found_by_criteria(criteria)
    log_warn("Security Log not found for criteria: #{criteria.inspect}")
  end

  # Logs a validation failure for a SecurityLog entry.
  def log_validation_failed(log, context, error_messages)
    user_info = log&.user_id ? "User ID #{log.user_id}" : 'No specific user'
    log_warn("Validation failed while #{context} for security log (ID: #{log&.pk || 'new'}, #{user_info}, Action: #{log&.action}): #{error_messages}")
  end

  # Logs when multiple SecurityLog entries are fetched.
  def log_security_logs_fetched(count)
    log_info("Fetched #{count} security logs")
  end

  # Logs when multiple SecurityLog entries are fetched with specific criteria.
  def log_security_logs_fetched_with_criteria(count, criteria)
    log_info("Fetched #{count} security logs with criteria: #{criteria.inspect}")
  end

  # Logs the update of a SecurityLog entry (if updates are allowed).
  def log_security_log_updated(log)
    log_info("Security Log updated: ID #{log.pk}, Action: #{log.action}, Object: #{log.object}")
  end

  # Logs the deletion of a SecurityLog entry (if deletions are allowed).
  def log_security_log_deleted(log)
    log_info("Security Log deleted: ID #{log.pk}, Action: #{log.action}, Object: #{log.object}")
  end

  # Logs when security logs for a specific user are fetched.
  def log_security_logs_for_user_fetched(user_id, count)
    log_info("Fetched #{count} security logs for User ID #{user_id}")
  end
end
