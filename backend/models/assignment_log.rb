# frozen_string_literal: true

# Represents a log entry for license assignment actions (e.g., assignment creation, deactivation)
# Tracks when and what actions were performed on license assignments for audit purposes
class AssignmentLog < Sequel::Model(:assignment_logs)
  plugin :timestamps, disabled: true

  set_primary_key :log_id

  many_to_one :license_assignment, key: :assignment_id

  def validate
    super
    validates_presence %i[log_timestamp action object]
  end
end
