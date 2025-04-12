Sequel.migration do
    up do
      create_table(:license_types) do
        primary_key :license_type_id, type: :Bignum
        String :variant, null: false
        Integer :max_assignment, null: false, default: 1
      end
    end

    down do
      drop_table(:license_types, cascade: true)
    end
end
