# frozen_string_literal: true

require_relative '../models/device'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'device_logging'
require_relative 'device_error_handling'

# Data Access Object for Device entities, handling database operations
class DeviceDAO < BaseDAO
  def self.model_class
    Device
  end

  def self.primary_key
    :device_id
  end

  include CrudOperations

  class << self
    include DeviceLogging
    include DeviceErrorHandling
  end

  class << self
    def find_by_serial_number(serial_number)
      return nil if serial_number.nil?

      find_one_by(serial_number: serial_number)
    end

    def find_with_licenses
      context = 'fetching devices with licenses'
      with_error_handling(context) do
        devices = model_class.eager(:license_assignments).exclude(license_assignments: nil).all
        log_devices_with_licenses_fetched(devices.size)
        devices
      end
    end
  end
end
