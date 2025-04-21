# frozen_string_literal: true

require 'bcrypt'

# Represents secure credential information for user authentication
# Handles password hashing and verification for user accounts
class UserCredential < Sequel::Model(:user_credentials)
  unrestrict_primary_key
  many_to_one :user, key: :user_id
  include BCrypt

  def password_plain=(plain_pass)
    self.password = plain_pass # Ruft den normalen password= Setter auf
  end

  def password=(new_password)
    raise ArgumentError, 'Password cannot be blank' if new_password.nil? || new_password.empty?

    @password = Password.create(new_password)
    self.password_hash = @password
  end

  def password
    @password ||= Password.new(password_hash) if password_hash
  end

  def authenticate(plain_password)
    password == plain_password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def validate
    super
    validates_presence :password_hash
  end
end
