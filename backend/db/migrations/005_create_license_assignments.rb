Sequel.migration do
    up do
      create_table(:license_assignments) do
        primary_key :assignment_id, type: :Bignum
        foreign_key :license_id, :licenses, type: :Bignum, null: false, key: :license_id, on_delete: :restrict
        foreign_key :user_id, :users, type: :Bignum, null: false, key: :user_id, on_delete: :restrict

        index [:license_id]
        index [:user_id]
        # A composite index to ensure that a user is only assigned a license once
        index [:license_id, :user_id], unique: true
      end
    end
  
    down do
      drop_table(:license_assignments, cascade: true)
    end
end
