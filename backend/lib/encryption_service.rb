# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'json'

module EncryptionService
  class DecryptionError < StandardError; end
  class EncryptionError < StandardError; end

  HEX_ENCRYPTION_KEY = ENV.fetch('ENCRYPTION_KEY') do
    puts 'ENCRYPTION_KEY not set, switching to Fallback'
    'f66a949ba03110ed6a886c3359eecadb04f7e4a87bad8959fc0fbd4c042ec775'
  end

  raise 'ENCRYPTION_KEY (HEX) must be 64 characters' unless HEX_ENCRYPTION_KEY.length == 64

  begin
    ENCRYPTION_KEY_BYTES = [HEX_ENCRYPTION_KEY].pack('H*')
  rescue ArgumentError
    raise "ENCRYPTION_KEY ('#{HEX_ENCRYPTION_KEY}') ist kein gültiger Hex-String."
  end

  if ENCRYPTION_KEY_BYTES.bytesize != 32
    raise "Verarbeiteter ENCRYPTION_KEY_BYTES muss 32 Bytes lang sein. Ist aber: #{ENCRYPTION_KEY_BYTES.bytesize} Bytes."
  end

  CIPHER_TYPE = 'aes-256-gcm'

  def self.encrypt(data_hash)
    cipher = OpenSSL::Cipher.new(CIPHER_TYPE).encrypt
    cipher.key = ENCRYPTION_KEY_BYTES
    iv = cipher.random_iv
    cipher.iv = iv

    json_payload = data_hash.to_json
    encrypted_data = cipher.update(json_payload) + cipher.final
    auth_tag = cipher.auth_tag

    packaged_data = iv + auth_tag + encrypted_data
    Base64.strict_encode64(packaged_data)
  end

  def self.decrypt(base64_packaged_data)
    return nil if base64_packaged_data.nil? || base64_packaged_data.empty?

    begin
      packaged_data = Base64.strict_decode64(base64_packaged_data)
    rescue ArgumentError => e
      # Ungültige Base64-Daten
      puts "EncryptionService: Invalid Base64 data for decryption: #{e.message}"
      raise DecryptionError, 'Invalid format for encrypted data (Base64).' # Eigene Fehlerklasse werfen
    end

    decipher = OpenSSL::Cipher.new(CIPHER_TYPE).decrypt
    decipher.key = ENCRYPTION_KEY_BYTES # Annahme: Diese Konstante existiert und ist korrekt

    iv_length = decipher.iv_len
    auth_tag_length = 16 # Für GCM

    if packaged_data.bytesize < iv_length + auth_tag_length
      puts 'EncryptionService: Packaged data too short for decryption.'
      raise DecryptionError, 'Encrypted data is incomplete.' # Eigene Fehlerklasse werfen
    end

    iv = packaged_data.slice!(0, iv_length)
    auth_tag = packaged_data.slice!(0, auth_tag_length)
    encrypted_data = packaged_data

    decipher.iv = iv
    decipher.auth_tag = auth_tag

    decrypted_json = decipher.update(encrypted_data) + decipher.final
    JSON.parse(decrypted_json, symbolize_names: true)
  rescue OpenSSL::Cipher::CipherError => e
    # Fehler während der OpenSSL Entschlüsselung (z.B. falscher Auth-Tag, falscher Schlüssel)
    puts "EncryptionService: CipherError during decryption: #{e.message}"
    raise DecryptionError, 'Failed to decrypt data (cipher error, possibly tampered or wrong key).' # Eigene Fehlerklasse werfen
  rescue JSON::ParserError => e
    # Entschlüsselter String ist kein valides JSON
    puts "EncryptionService: JSON::ParserError after decryption: #{e.message}"
    raise DecryptionError, 'Decrypted data is not valid JSON.' # Eigene Fehlerklasse werfen
  rescue StandardError => e # Fängt andere unerwartete Fehler innerhalb von decrypt
    puts "EncryptionService: Unexpected error during decryption: #{e.class} - #{e.message}"
    raise DecryptionError, 'An unexpected error occurred during data decryption.'
  end
end
