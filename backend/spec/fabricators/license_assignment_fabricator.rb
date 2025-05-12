# frozen_string_literal: true

Fabricator(:base_license_assignment, class_name: :license_assignment) do
  license
  assignment_date { Time.now }
  is_active { true }
end

Fabricator(:user_license_assignment, from: :base_license_assignment) do
  user { Fabricate(:user) }
end

Fabricator(:device_license_assignment, from: :base_license_assignment) do
  device { Fabricate(:device) }
end

Fabricator(:license_assignment, from: :user_license_assignment)
