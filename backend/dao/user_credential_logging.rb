module UserCredentialLogging
    
    def log_credential_created(credential)
      log_info("UserCredential created for user_id: #{credential.user_id}")
    end
  
    def log_credential_found(credential)
      log_info("UserCredential found for user_id: #{credential.user_id}")
    end
  
    def log_credential_not_found(user_id)
      log_warn("UserCredential for user_id #{user_id} not found")
    end
  
    def log_validation_failed(credential, context)
      log_warn("Validation failed while #{context} credential for user_id '#{credential.user_id || 'new'}': #{credential.errors.inspect}")
    end
  
    def log_credential_updated(credential)
      log_info("UserCredential updated for user_id: #{credential.user_id}")
    end
  
     def log_password_updated(credential)
      log_info("Password updated successfully for user_id: #{credential.user_id}")
    end
  
    def log_credential_deleted(credential)
      log_info("UserCredential deleted for user_id: #{credential.user_id}")
    end
end
