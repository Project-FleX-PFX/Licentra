module UserCredentialLogging

  def log_created(credential)
    log_info("UserCredential created for user_id: #{credential.user_id}")
  end

  def log_found(credential)
    log_info("UserCredential found for user_id: #{credential.user_id}")
  end

  def log_found_by_criteria(criteria, credential)
    log_info("UserCredential found by #{criteria.inspect}: user_id #{credential.user_id}")
  end

  def log_fetched(count)
    log_info("Fetched #{count} user credentials")
  end

  def log_fetched_with_criteria(count, criteria)
    log_info("Fetched #{count} user credentials with criteria: #{criteria.inspect}")
  end

  def log_updated(credential)
    log_info("UserCredential updated for user_id: #{credential.user_id}")
  end

  def log_deleted(credential)
    log_info("UserCredential deleted for user_id: #{credential.user_id}")
  end

  def log_validation_failed(credential, context)
    log_warn("Validation failed while #{context} credential for user_id '#{credential.user_id || 'new'}': #{credential.errors.inspect}")
  end

  def log_record_not_found(user_id)
    log_warn("UserCredential for user_id #{user_id} not found")
  end

  def log_record_not_found_by_criteria(criteria)
    log_warn("UserCredential not found for criteria: #{criteria.inspect}")
  end

  def log_password_updated(credential)
    log_info("Password updated successfully for user_id: #{credential.user_id}")
  end
  
end
