Sequel.migration do
    change do
      create_table(:roles) do
        primary_key :role_id
        String :role_name, null: false, unique: true
      end
    end
end
