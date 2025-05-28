# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:app_configurations) do
      String :key, primary_key: true
      String :encrypted_value_package, text: true, null: true # Speichert das Base64-kodierte Paket (IV + Auth Tag + Ciphertext)
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
