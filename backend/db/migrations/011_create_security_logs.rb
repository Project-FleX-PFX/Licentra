# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:security_logs) do
      primary_key :log_id
      Integer :user_id, null: false
      String :username, null: false
      String :email
      DateTime :log_timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      String :action, null: false
      String :object, null: false
      Text :details
    end
  end
end
