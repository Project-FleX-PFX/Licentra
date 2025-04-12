Sequel.migration do
  change do
    create_table(:products) do
      primary_key :product_id
      String :product_name, null: false, unique: true
    end
  end
end
