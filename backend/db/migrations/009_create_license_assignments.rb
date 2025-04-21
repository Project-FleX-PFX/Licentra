# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:license_assignments) do
      primary_key :assignment_id
      foreign_key :license_id, :licenses, null: false, on_delete: :cascade
      foreign_key :user_id, :users, null: true, on_delete: :set_null
      foreign_key :device_id, :devices, null: true, on_delete: :set_null
      DateTime :assignment_date, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :assignment_expire_date, null: true
      Text :notes
      Boolean :is_active, null: false, default: true

      # to ensure that either user_id or device_id is set
      constraint(:user_or_device_check, 'user_id IS NOT NULL OR device_id IS NOT NULL')

      index %i[license_id user_id]
      index %i[license_id device_id]
      index :is_active
    end
  end
end
