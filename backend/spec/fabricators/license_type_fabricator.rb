# frozen_string_literal: true

Fabricator(:license_type) do
  type_name { sequence(:type_name) { |i| "License Type #{i}" } }
  description { 'Description for license type' } # Optional, as available in the schema
end
