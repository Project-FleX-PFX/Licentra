# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:license_types) do
      primary_key :license_type_id
      String :type_name, null: false, unique: true
      Text :description
    end
  end
end
