# frozen_string_literal: true

# Represents an immutable log entry for security-relevant actions within the application.
# Each log records what action was performed, on what kind of object,
# by whom (denormalized user data), and when, along with any relevant details.
class SecurityLog < Sequel::Model(:security_logs)
  plugin :timestamps, disabled: true

  set_primary_key :log_id

  def validate
    super
    validates_presence %i[
      user_id username
      log_timestamp action object
    ]
  end

  def before_update
    raise Sequel::ValidationFailed, 'SecurityLog entries are immutable and cannot be updated.'
  end
end
