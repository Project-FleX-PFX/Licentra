Sequel.migration do
    up do
      create_table(:licenses) do
        primary_key :license_id, type: :Bignum
        foreign_key :product_id, :products, type: :Bignum, null: false, key: :product_id, on_delete: :restrict
        foreign_key :license_type_id, :license_types, type: :Bignum, null: false, key: :license_type_id, on_delete: :restrict
        String :license_key, null: false, unique: true
      end
    end

    down do
      drop_table(:licenses, cascade: true)
    end
end
