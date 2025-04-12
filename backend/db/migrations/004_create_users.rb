Sequel.migration do
  change do
    create_table(:users) do
      primary_key :user_id
      String :username, null: false, unique: true
      String :email, unique: true
      String :first_name
      String :last_name
      Boolean :is_active, null: false, default: true

      index :email
    end
  end
end
