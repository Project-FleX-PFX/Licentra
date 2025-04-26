# frozen_string_literal: true

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
  action { %w[ASSIGNED ACTIVATED DEACTIVATED].sample }
  details { 'Test log entry' }
end
