# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:devices) do
      primary_key :device_id
      String :device_name, null: false
      String :serial_number, unique: true
      Text :notes

      index :serial_number
    end
  end
end
