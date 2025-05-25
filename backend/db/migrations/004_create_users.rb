# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:users) do
      primary_key :user_id
      String :username, null: false, unique: true
      String :email, unique: true
      String :first_name
      String :last_name
      Boolean :is_active, null: false, default: true
      Integer :failed_login_attempts, null: false, default: 0
      DateTime :locked_at
      DateTime :last_password_reset_requested_at
      index :email
    end
  end
end
