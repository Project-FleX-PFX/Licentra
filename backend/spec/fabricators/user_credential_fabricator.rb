# frozen_string_literal: true

require 'bcrypt'

Fabricator(:user_credential) do
  password { 'supersecret' }
end
