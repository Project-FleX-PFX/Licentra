# frozen_string_literal: true

require 'securerandom'

Fabricator(:device) do
  device_name { sequence(:device_name) { |n| "TestDevice-#{n}" } }
  serial_number { "SN#{SecureRandom.hex(8).upcase}" }
end
