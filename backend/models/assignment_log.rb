# frozen_string_literal: true

# Represents an immutable log entry for license assignment actions.
# Tracks when and what actions were performed, along with denormalized
# details of the license and user at the time of the action.
class AssignmentLog < Sequel::Model(:assignment_logs)
  plugin :timestamps, disabled: true

  set_primary_key :log_id

  def validate
    super
    validates_presence %i[
      license_id license_name
      user_id username email
      log_timestamp action object
    ]
  end

  def before_update
    raise Sequel::ValidationFailed, 'AssignmentLog entries are immutable and cannot be updated.'
  end
end
