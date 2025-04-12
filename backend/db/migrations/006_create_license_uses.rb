Sequel.migration do
    up do
      create_table(:license_uses) do
        primary_key :use_id, type: :Bignum
        foreign_key :assignment_id, :license_assignments, type: :Bignum, null: false, key: :assignment_id, on_delete: :cascade
        DateTime :usage_date, null: false, default: Sequel::CURRENT_TIMESTAMP
        DateTime :expire_date, null: true
  
        index [:assignment_id]
      end
    end
  
    down do
      drop_table(:license_uses, cascade: true)
    end
end
