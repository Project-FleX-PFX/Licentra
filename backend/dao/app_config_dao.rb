require_relative '../lib/encryption_service'

# dao/app_config_dao.rb
module AppConfigDAO
  SMTP_SETTINGS_KEY = 'smtp_settings'.freeze
  def self.save_smtp_settings(settings_from_form_hash)
    current_decrypted_settings = get_smtp_settings || {}
    new_password_input = settings_from_form_hash[:smtp_password_from_form]
    settings_to_encrypt = settings_from_form_hash.dup
    settings_to_encrypt.delete(:smtp_password_from_form)

    current_decrypted_settings.each do |key, value|
      settings_to_encrypt[key] = value unless settings_to_encrypt.key?(key) || key == :password || key == :password_placeholder
    end

    if new_password_input && !new_password_input.empty?
      settings_to_encrypt[:password] = new_password_input # Speichere das neue Klartextpasswort für die Verschlüsselung
    else
      if current_decrypted_settings.key?(:password)
        settings_to_encrypt[:password] = current_decrypted_settings[:password]
      else
        settings_to_encrypt.delete(:password)
      end
    end

    settings_to_encrypt.delete(:password_placeholder)

    encrypted_package = EncryptionService.encrypt(settings_to_encrypt)

    DB[:app_configurations].insert_conflict(
      target: :key,
      update: { encrypted_value_package: encrypted_package, updated_at: Time.now }
    ).insert(key: SMTP_SETTINGS_KEY, encrypted_value_package: encrypted_package, updated_at: Time.now)
    true
  rescue => e
    puts "Error while saving SMTP settings: #{e.message}\n#{e.backtrace.join("\n")}" # Backtrace für mehr Infos
    false
  end

  def self.get_smtp_settings
    record = DB[:app_configurations].where(key: SMTP_SETTINGS_KEY).first
    return nil unless record && record[:encrypted_value_package]

    decrypted_settings = EncryptionService.decrypt(record[:encrypted_value_package])
    decrypted_settings
  end
end
