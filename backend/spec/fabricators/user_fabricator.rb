# frozen_string_literal: true

Fabricator(:user) do
  username { sequence(:username) { |i| "testuser#{i}" } }
  email { sequence(:email) { |i| "test#{i}@example.com" } }
  is_active { true }
end
