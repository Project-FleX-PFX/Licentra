require_relative 'errors'

module UserCredentialErrorHandling

  def handle_validation_error(credential, context)
    log_validation_failed(credential, context)
    raise ValidationError.new("Validation failed while #{context}", credential.errors, credential)
  end

  def handle_record_not_found(user_id)
    log_credential_not_found(user_id) # Aus Logging-Modul
    raise RecordNotFound, "UserCredential for user_id #{user_id} not found"
  end

end
