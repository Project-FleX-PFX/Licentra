# frozen_string_literal: true

module RoutesErrorHelpers
  def dao_validation_format_creation_error(error)
    error_messages_array = error.errors.full_messages

    if error_messages_array.any?
      formatted_error_string = format_error_message(error_messages_array)
      flash[:error] = "User creation failed due to validation errors:#{formatted_error_string}"
    else
      flash[:error] = 'User creation failed due to validation errors. Please check your input'
    end
  end

  def dao_validation_format_update_error(error)
    error_messages_array = error.errors.full_messages

    if error_messages_array.any?
      formatted_error_string = format_error_message(error_messages_array)
      flash[:error] = "Updating user failed due to validation errors:#{formatted_error_string}"
    else
      flash[:error] = 'Updating user failed due to validation errors. Please check your input'
    end
  end

  def dao_admin_protection_error(error)
    flash[:error] = "Admin protection: #{error.message}"
  end

  private

  def format_error_message(error_messages_array)
    error_messages_array.map.with_index do |message, index|
      if index.zero?
        " #{message}"
      else
        ", #{message}"
      end
    end.join
  end

  def handle_profile_service_errors
    yield
  rescue DAO::RecordNotFound
    flash[:error] = 'The requested profile was not found.'
    halt 404, { error: 'Profile not found.' }.to_json
  rescue DAO::ValidationError => e
    dao_validation_format_profile_error(e)
    halt 422, { error: e.message }.to_json
  rescue ProfileService::InvalidFieldError => e
    flash[:error] = e.message
    halt 400, { error: e.message }.to_json
  rescue ProfileService::ProfileUpdateError => e
    flash[:error] = e.message
    halt 422, { error: e.message }.to_json
  rescue UserCredential::PasswordPolicyError => e
    flash[:error] = "Password policy violation: #{e.message}"
    halt 422, { error: "Password policy violation: #{e.message}" }.to_json
  rescue Sequel::ValidationFailed => e
    full_message = "Validation failed: #{e.errors.full_messages.join(', ')}"
    flash[:error] = full_message
    halt 422, { error: full_message }.to_json
  rescue Sequel::UniqueConstraintViolation => e
    flash[:error] = 'This value is already taken by another user.'
    halt 422, { error: 'This value is already taken by another user.' }.to_json
  rescue StandardError => e
    logger.error "Unexpected error in profile update: #{e.message}\n#{e.backtrace.join("\n")}"
    flash[:error] = 'An unexpected server error occurred while updating your profile.'
    halt 500, { error: 'An unexpected server error occurred while updating your profile.' }.to_json
  end

  def dao_validation_format_profile_error(error)
    error_messages_array = error.errors.full_messages

    if error_messages_array.any?
      formatted_error_string = format_error_message(error_messages_array)
      flash[:error] = "Profile update failed due to validation errors:#{formatted_error_string}"
    else
      flash[:error] = 'Profile update failed due to validation errors. Please check your input'
    end
  end
end
