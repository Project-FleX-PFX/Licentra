require_relative '../models/device'
require_relative 'base_dao'
require_relative 'device_logging'
require_relative 'device_error_handling'

class DeviceDAO < BaseDAO
  class << self
    include DeviceLogging
    include DeviceErrorHandling

    # CREATE
    def create(attributes)
      with_error_handling("creating device") do
        device = Device.new(attributes)
        if device.valid?
          device.save
          log_device_created(device)
          device
        else
          handle_validation_error(device, "creating device")
        end
      end
    end

    # READ
    def find!(id)
      with_error_handling("finding device with ID #{id}") do
        device = Device[id]
        unless device
          handle_record_not_found(id)
        end
        log_device_found(device)
        device
      end
    end

    def find(id)
      with_error_handling("finding device with ID #{id}") do
        device = Device[id]
        log_device_found(device) if device
        device
      end
    end

    def find_one_by(criteria)
      with_error_handling("finding device by criteria") do
        device = Device.first(criteria)
        log_device_found_by_criteria(criteria, device) if device
        device
      end
    end

    def find_one_by!(criteria)
      with_error_handling("finding device by criteria") do
        device = find_one_by(criteria)
        unless device
          handle_record_not_found_by_criteria(criteria)
        end
        device
      end
    end

    def find_by_serial_number(serial_number)
      return nil if serial_number.nil?
      find_one_by(serial_number: serial_number)
    end

    def all(options = {})
      with_error_handling("fetching all devices") do
        dataset = Device.dataset
        dataset = dataset.where(options[:where]) if options[:where]
        dataset = dataset.order(options[:order]) if options[:order]
        devices = dataset.all
        log_devices_fetched(devices.size)
        devices
      end
    end

    def where(criteria)
      with_error_handling("filtering devices by criteria") do
        devices = Device.where(criteria).all
        log_devices_fetched_with_criteria(devices.size, criteria)
        devices
      end
    end

    # UPDATE
    def update(id, attributes)
      with_error_handling("updating device with ID #{id}") do
        device = find!(id)
        device.update(attributes)
        log_device_updated(device)
        device
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting device with ID #{id}") do
        device = find!(id)
        device.destroy
        log_device_deleted(device)
        true
      end
    end

    # SPECIAL QUERIES
    def find_with_licenses
      with_error_handling("fetching devices with licenses") do
        devices = Device.eager(:license_assignments).exclude(license_assignments: nil).all
        log_devices_with_licenses_fetched(devices.size)
        devices
      end
    end
  end
end
