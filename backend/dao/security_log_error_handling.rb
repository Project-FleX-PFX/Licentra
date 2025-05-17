# frozen_string_literal: true

require_relative 'errors'

# Error handling module for the SecurityLogDAO
module SecurityLogErrorHandling
  include DAO

  # Handles validation errors for SecurityLog.
  # Logs the failure and raises a DAO::ValidationError.
  # @param log [SecurityLog] The SecurityLog instance that failed validation.
  # @param context [String] Description of the operation being performed.
  # @param messages [String, nil] Optional pre-formatted error messages.
  def handle_validation_error(log, context, messages = nil)
    error_messages = messages || log&.errors&.full_messages&.join('; ') || 'Unknown validation error'
    log_validation_failed(log, context, error_messages)
    raise DAO::ValidationError.new("Validation failed while #{context}: #{error_messages}", log&.errors, log)
  end

  # Handles cases where a SecurityLog is not found by its ID.
  # Logs the event and raises a DAO::RecordNotFound error.
  # @param id [Integer, String] The ID of the SecurityLog that was not found.
  # @param model_name [String] The name of the model (default: 'SecurityLog').
  def handle_record_not_found(id, model_name = 'SecurityLog')
    log_security_log_not_found(id)
    raise DAO::RecordNotFound, "#{model_name} with ID #{id} not found"
  end

  # Handles cases where a SecurityLog is not found by a given set of criteria.
  # Logs the event and raises a DAO::RecordNotFound error.
  # @param criteria [Hash] The criteria used for the search.
  # @param model_name [String] The name of the model (default: 'SecurityLog').
  def handle_record_not_found_by_criteria(criteria, model_name = 'SecurityLog')
    log_security_log_not_found_by_criteria(criteria)
    raise DAO::RecordNotFound, "#{model_name} not found for criteria: #{criteria.inspect}"
  end
end
