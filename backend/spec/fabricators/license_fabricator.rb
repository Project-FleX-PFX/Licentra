# frozen_string_literal: true

Fabricator(:license) do
  product
  license_type
  license_key { sequence(:license_key) { |i| "LICENSE-KEY-#{i}" } }
  seat_count { 5 }
  status { 'Active' } # Statt is_active
end
