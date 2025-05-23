require 'bcrypt'
require 'securerandom'

module PasswordResetTokenDAO
  TOKEN_VALIDITY_HOURS = 1

  def self.create_token_for_user(user_id)
    klartext_token = SecureRandom.urlsafe_base64(32)
    token_hash = BCrypt::Password.create(klartext_token)
    expires_at = Time.now + (TOKEN_VALIDITY_HOURS * 60 * 60)

    DB[:password_reset_tokens].where(user_id: user_id).delete

    DB[:password_reset_tokens].insert(
      user_id: user_id,
      token_hash: token_hash,
      expires_at: expires_at
    )
    klartext_token
  rescue Sequel::DatabaseError => e
    puts "Database error while creating password reset token: #{e.message}"
    nil
  end

  def self.find_user_by_token(klartext_token)
    return nil if klartext_token.nil? || klartext_token.empty?

    active_tokens = DB[:password_reset_tokens].where(Sequel.lit('expires_at > ?', Time.now)).all

    active_tokens.each do |token_record|
      if BCrypt::Password.new(token_record[:token_hash]) == klartext_token
        user = UserDAO.find_by_id(token_record[:user_id])

        return { user: user, token_record_id: token_record[:id] } if user
      end
    end
    nil
  end

  def self.delete_token(token_record_id)
    DB[:password_reset_tokens].where(id: token_record_id).delete
  end
end
