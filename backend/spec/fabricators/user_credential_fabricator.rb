# frozen_string_literal: true

require 'bcrypt'
require 'faker'

Fabricator(:user_credential) do
  password do
    Faker::Internet.password(min_length: UserCredential::MIN_PASSWORD_LENGTH, mix_case: true, special_characters: true)
  end
end
