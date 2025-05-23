require 'openssl'
require 'base64'
require 'json'

module EncryptionService
  HEX_ENCRYPTION_KEY = ENV.fetch('ENCRYPTION_KEY') do
    puts "ENCRYPTION_KEY not set, switching to Fallback"
    "f66a949ba03110ed6a886c3359eecadb04f7e4a87bad8959fc0fbd4c042ec775"
  end

  raise "ENCRYPTION_KEY (HEX) must be 64 characters" unless HEX_ENCRYPTION_KEY.length == 64

  begin
    ENCRYPTION_KEY_BYTES = [HEX_ENCRYPTION_KEY].pack('H*')
  rescue ArgumentError
    raise "ENCRYPTION_KEY ('#{HEX_ENCRYPTION_KEY}') ist kein gültiger Hex-String."
  end

  if ENCRYPTION_KEY_BYTES.bytesize != 32
    raise "Verarbeiteter ENCRYPTION_KEY_BYTES muss 32 Bytes lang sein. Ist aber: #{ENCRYPTION_KEY_BYTES.bytesize} Bytes."
  end

  CIPHER_TYPE = "aes-256-gcm".freeze

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
    rescue ArgumentError
      puts "Error while decrypting smtp settings: Invalid Base64 data"
      return nil
    end


    decipher = OpenSSL::Cipher.new(CIPHER_TYPE).decrypt
    decipher.key = ENCRYPTION_KEY_BYTES

    iv_length = decipher.iv_len
    auth_tag_length = 16

    if packaged_data.bytesize < iv_length + auth_tag_length
      puts "Error while decrypting smtp settings: Packaged data too short."
      return nil
    end

    iv = packaged_data.slice!(0, iv_length)
    auth_tag = packaged_data.slice!(0, auth_tag_length)
    encrypted_data = packaged_data # Der Rest

    decipher.iv = iv
    decipher.auth_tag = auth_tag

    decrypted_json = decipher.update(encrypted_data) + decipher.final
    JSON.parse(decrypted_json, symbolize_names: true)
  rescue OpenSSL::Cipher::CipherError => e
    puts "Error while decrypting smtp settings (CipherError, likely bad key/tag): #{e.class}: #{e.message}"
    nil
  rescue JSON::ParserError => e
    puts "Error while decrypting smtp settings (JSON ParserError): #{e.class}: #{e.message}"
    nil
  rescue StandardError => e
    puts "Unexpected error while decrypting smtp settings: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
    nil
  end
end
