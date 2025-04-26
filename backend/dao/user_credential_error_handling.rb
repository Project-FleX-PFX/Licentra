# frozen_string_literal: true

require_relative 'errors'

# Error handling specific to UserCredential operations
module UserCredentialErrorHandling
  include DAO

  def handle_validation_error(credential, context)
    log_validation_failed(credential, context)
    raise ValidationError.new("Validation failed while #{context}", credential.errors, credential)
  end

  def handle_record_not_found(user_id)
    log_record_not_found(user_id)
    raise RecordNotFound, "UserCredential for user_id #{user_id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise RecordNotFound, "UserCredential not found for criteria: #{criteria.inspect}"
  end
end
