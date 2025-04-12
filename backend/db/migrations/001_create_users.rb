Sequel.migration do
    up do
      create_table(:users) do
        primary_key :user_id, type: :Bignum
        String :username, null: false, unique: true
        String :password, null: false
        Boolean :is_admin, null: false, default: false
      end
    end

    down do
      drop_table(:users, cascade: true)
    end
end
