# frozen_string_literal: true

Fabricator(:role) do
  role_name { sequence(:role_name) { |i| "TestRole#{i}" } }
end
