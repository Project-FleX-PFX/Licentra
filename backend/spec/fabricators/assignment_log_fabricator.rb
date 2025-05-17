# frozen_string_literal: true

require 'faker'

Fabricator(:assignment_log) do
  # Use an existing LicenseAssignment or create a new one
  transient license_assignment: nil

  assignment_id do |attrs|
    if attrs[:license_assignment]
      attrs[:license_assignment].assignment_id
    else
      Fabricate(:license_assignment).assignment_id
    end
  end

  log_timestamp { Time.now }
  action { %w[APPROVED CANCELED ACTIVATED DEACTIVATED].sample }
  object { 'License 42' }
  details { Faker::Lorem.sentence }
end
