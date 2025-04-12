Sequel.migration do
    up do
      create_table(:products) do
        primary_key :product_id, type: :Bignum
        String :product_name, null: false
      end
    end
  
    down do
      drop_table(:products, cascade: true)
    end
end
