# frozen_string_literal: true

require 'faker'

Fabricator(:user) do
  username { Faker::Internet.unique.username(specifier: 5..12) }
  email    { Faker::Internet.unique.email }
  is_active { true }
end
