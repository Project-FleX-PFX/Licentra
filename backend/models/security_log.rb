# frozen_string_literal: true

# Represents a log entry for security-relevant actions within the application.
# Each log records what action was performed, on what kind of object,
# by whom (if applicable), and when, along with any relevant details.
class SecurityLog < Sequel::Model(:security_logs)
  plugin :timestamps, disabled: true

  set_primary_key :log_id

  # Associations
  # A security log can optionally belong to a user.
  # If the user is deleted, the user_id in the log will be set to NULL
  many_to_one :user, key: :user_id

  # Validations
  def validate
    super
    validates_presence %i[log_timestamp action object]
  end
end
