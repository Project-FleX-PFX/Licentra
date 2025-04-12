Sequel.migration do
  change do
    create_table(:licenses) do
      primary_key :license_id
      foreign_key :product_id, :products, null: false, on_delete: :restrict
      foreign_key :license_type_id, :license_types, null: false, on_delete: :restrict
      String :license_key
      String :license_name
      Integer :seat_count, null: false, default: 1
      Date :purchase_date
      Date :expire_date
      BigDecimal :cost, size: [10, 2]
      String :currency, size: 3
      String :vendor
      Text :notes
      String :status, default: 'Active' # e.g. Active, Expired, Archived

      index :license_key
      index :expire_date
      index :status
    end
  end
end
