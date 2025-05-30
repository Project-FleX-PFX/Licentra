# frozen_string_literal: true

require_relative '../dao/user_dao'
require_relative '../dao/user_credential_dao'
require_relative '../dao/security_log_dao'

# Service class for profiles
class ProfileService
  ALLOWED_FIELDS = %w[username email password].freeze

  # Custom exceptions für bessere Fehlerbehandlung
  class ProfileUpdateError < StandardError; end
  class InvalidFieldError < ProfileUpdateError; end

  class << self
    def update_profile(user_performing_update, field, value)
      raise InvalidFieldError, 'Invalid field' unless ALLOWED_FIELDS.include?(field)

      target_user = user_performing_update

      case field
      when 'username'
        update_username(user_performing_update, target_user, value)
      when 'email'
        update_email(user_performing_update, target_user, value)
      when 'password'
        update_password(user_performing_update, target_user, value)
      else
        raise InvalidFieldError, 'Invalid field operation'
      end
    end

    private

    def update_username(user_performing_update, target_user, new_username)
      old_username = target_user.username

      raise ProfileUpdateError, 'Username cannot be empty.' if new_username.nil? || new_username.strip.empty?
      raise ProfileUpdateError, 'Username already exists.' if username_taken?(new_username, target_user.user_id)

      updated_user = UserDAO.update(target_user.user_id, username: new_username)
      raise ProfileUpdateError, 'Failed to update username.' unless updated_user

      SecurityLogDAO.log_user_updated(
        acting_user: user_performing_update,
        updated_user: updated_user,
        changes_description: "Username changed from '#{old_username}' to '#{new_username}'."
      )

      updated_user
    end

    def update_email(user_performing_update, target_user, new_email)
      old_email = target_user.email

      raise ProfileUpdateError, 'Email cannot be empty.' if new_email.nil? || new_email.strip.empty?
      raise ProfileUpdateError, 'Email already exists.' if email_taken?(new_email, target_user.user_id)

      updated_user = UserDAO.update(target_user.user_id, email: new_email)
      raise ProfileUpdateError, 'Failed to update email.' unless updated_user

      SecurityLogDAO.log_user_updated(
        acting_user: user_performing_update,
        updated_user: updated_user,
        changes_description: "Email changed from '#{old_email}' to '#{new_email}'."
      )

      updated_user
    end

    def update_password(user_performing_update, target_user, new_password)
      raise ProfileUpdateError, 'Password cannot be empty.' if new_password.nil? || new_password.empty?

      updated_credential = UserCredentialDAO.update_password(target_user.user_id, new_password)
      raise ProfileUpdateError, 'Failed to update password for an unknown reason.' unless updated_credential

      SecurityLogDAO.log_password_changed(user_who_changed_password: target_user)
      updated_credential
    end

    def username_taken?(username, current_user_id)
      existing_user = UserDAO.find_by_username(username)
      existing_user && existing_user.user_id != current_user_id
    end

    def email_taken?(email, current_user_id)
      existing_user = UserDAO.find_by_email(email)
      existing_user && existing_user.user_id != current_user_id
    end
  end
end
