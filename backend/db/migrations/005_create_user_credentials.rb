# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:user_credentials) do
      foreign_key :user_id, :users, primary_key: true, on_delete: :cascade
      String :password_hash, null: false
    end
  end
end
