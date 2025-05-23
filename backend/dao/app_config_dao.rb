require_relative '../lib/encryption_service'

module AppConfigDAO
  SMTP_SETTINGS_KEY = 'smtp_settings'.freeze

  def self.save_smtp_settings(settings_hash)
    current_decrypted_settings = get_smtp_settings || {}
    new_password = settings_hash.delete(:smtp_password_from_form)

    if new_password && !new_password.empty?
      settings_to_encrypt = current_decrypted_settings.merge(settings_hash)
      settings_to_encrypt[:password] = new_password
    else
      settings_to_encrypt = current_decrypted_settings.merge(settings_hash)
    end

    settings_to_encrypt.delete(:smtp_password_from_form)
    settings_to_encrypt.delete(:password_placeholder)

    encrypted_package = EncryptionService.encrypt(settings_to_encrypt)

    DB[:app_configurations].insert_conflict(
      target: :key,
      update: { encrypted_value_package: encrypted_package, updated_at: Time.now }
    ).insert(key: SMTP_SETTINGS_KEY, encrypted_value_package: encrypted_package, updated_at: Time.now)
    true
  rescue => e
    puts "Error while saving SMTP settings: #{e.message}"
    false
  end

  def self.get_smtp_settings
    record = DB[:app_configurations].where(key: SMTP_SETTINGS_KEY).first
    return nil unless record && record[:encrypted_value_package]

    decrypted_settings = EncryptionService.decrypt(record[:encrypted_value_package])
    if decrypted_settings && decrypted_settings[:password] && !decrypted_settings[:password].empty?
      decrypted_settings[:password_placeholder] = "*********"
    end
    decrypted_settings
  end
end