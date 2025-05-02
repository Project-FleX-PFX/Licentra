# frozen_string_literal: true

# Service class for profiles
class ProfileService
  ALLOWED_FIELDS = %w[username email password].freeze

  class << self
    def update_profile(user, field, value)
      return invalid_field_response unless ALLOWED_FIELDS.include?(field)

      case field
      when 'username'
        update_username(user, value)
      when 'email'
        update_email(user, value)
      when 'password'
        update_password(user, value)
      end
    end

    private

    def invalid_field_response
      { success: false, message: 'Invalid field' }
    end

    def update_username(user, username)
      return { success: false, message: 'Username already exists' } if username_taken?(username, user.user_id)

      UserDAO.update(user.user_id, username: username)
      { success: true }
    end

    def update_email(user, email)
      return { success: false, message: 'Email already exists' } if email_taken?(email, user.user_id)

      UserDAO.update(user.user_id, email: email)
      { success: true }
    end

    def update_password(user, password)
      UserCredentialDAO.update_password(user.user_id, password)
      { success: true }
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
