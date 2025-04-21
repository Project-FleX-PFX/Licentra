# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:assignment_logs) do
      primary_key :log_id
      foreign_key :assignment_id, :license_assignments, null: true, on_delete: :set_null
      DateTime :log_timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      String :action, null: false # e.g. 'ASSIGNED', 'REVOKED', 'ACTIVATED', 'DEACTIVATED'
      Text :details
    end
  end
end
