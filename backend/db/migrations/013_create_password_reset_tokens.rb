# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:password_reset_tokens) do
      primary_key :id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      String :token_hash, null: false, unique: true
      DateTime :expires_at, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      index :user_id
    end
  end
end
