# frozen_string_literal: true

require 'bcrypt'

# Represents secure credential information for user authentication
# Handles password hashing and verification for user accounts
class UserCredential < Sequel::Model(:user_credentials)
  unrestrict_primary_key
  many_to_one :user, key: :user_id
  include BCrypt

  # Custom error for password policy violations
  class PasswordPolicyError < StandardError; end

  MIN_PASSWORD_LENGTH = 10
  REGEX_LOWERCASE      = /[a-z]/.freeze
  REGEX_UPPERCASE      = /[A-Z]/.freeze
  REGEX_DIGIT          = /\d/.freeze
  REGEX_SPECIAL_CHAR   = %r{[!"#$%&'()*+,./:;<=>?@\[\\\]\^_`{|}~-]}.freeze
  FORBIDDEN_STRINGS = %w[password licentra].freeze

  def password=(new_password)
    validate_password_policy!(new_password)

    @password = Password.create(new_password)
    self.password_hash = @password
  end

  def password
    @password ||= Password.new(password_hash) if password_hash
  end

  def authenticate(plain_password)
    return false if plain_password.nil? || plain_password.empty?

    password == plain_password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def validate
    super
    validates_presence :password_hash
  end

  private

  def validate_password_policy!(plain_password)
    all_errors = []

    error = _validate_non_empty(plain_password)
    if error
      all_errors << error
      raise PasswordPolicyError, all_errors.join("\n")
    end

    all_errors << _validate_min_length(plain_password)

    all_errors << _validate_character_classes(plain_password)

    all_errors.concat(_validate_forbidden_strings(plain_password))

    all_errors.compact!

    raise PasswordPolicyError, all_errors.join("\n") unless all_errors.empty?
  end

  def _validate_non_empty(password_value)
    return 'Password must not be empty.' if password_value.nil? || password_value.empty?

    nil
  end

  def _validate_min_length(password_value)
    if password_value.length < MIN_PASSWORD_LENGTH
      return "Password must be at least #{MIN_PASSWORD_LENGTH} characters long."
    end

    nil
  end

  def _validate_character_classes(password_value)
    missing_character_types = []
    missing_character_types << 'Lower case letters' unless password_value.match?(REGEX_LOWERCASE)
    missing_character_types << 'Upper case letters' unless password_value.match?(REGEX_UPPERCASE)
    missing_character_types << 'Digits' unless password_value.match?(REGEX_DIGIT)
    missing_character_types << 'Special characters' unless password_value.match?(REGEX_SPECIAL_CHAR)

    unless missing_character_types.empty?
      return "Password must contain at least one of each of the following types: #{missing_character_types.join(', ')}."
    end

    nil
  end

  def _validate_forbidden_strings(password_value)
    errors = []
    password_value_downcase = password_value.downcase
    FORBIDDEN_STRINGS.each do |forbidden_word|
      if password_value_downcase.include?(forbidden_word.downcase)
        errors << "Password must not contain the word: '#{forbidden_word}'."
      end
    end
    errors
  end
end
