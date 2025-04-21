# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:user_roles) do
      primary_key :user_role_id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      foreign_key :role_id, :roles, null: false, on_delete: :cascade

      unique %i[user_id role_id]
      index %i[role_id user_id]
    end
  end
end
