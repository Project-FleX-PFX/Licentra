Sequel.migration do
  change do
    create_table :users do
      primary_key :id
      String :username, null: false
      String :password_digest, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      
      index :username, unique: true
    end
  end
end

