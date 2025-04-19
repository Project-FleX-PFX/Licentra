module DeviceLogging
  
  def log_created(device)
    log_info("Device created: #{device.inspect}")
  end

  def log_found(device)
    log_info("Device found: #{device.inspect}")
  end

   def log_found_by_criteria(criteria, device)
    log_info("Device found by #{criteria.inspect}: #{device.inspect}")
  end

  def log_fetched(count)
     log_info("Fetched #{count} devices")
  end

  def log_fetched_with_criteria(count, criteria)
    log_info("Fetched #{count} devices with criteria: #{criteria.inspect}")
  end

  def log_updated(device)
    log_info("Device updated: #{device.inspect}")
  end

  def log_deleted(device)
    log_info("Device deleted: #{device.inspect}")
  end

  def log_devices_with_licenses_fetched(count)
    log_info("Fetched #{count} devices with licenses assigned")
  end

  def log_validation_failed(device, context)
     log_warn("Validation failed while #{context}: #{device.errors.inspect}")
  end

  def log_record_not_found(id)
     log_warn("Device with ID #{id} not found")
  end

   def log_record_not_found_by_criteria(criteria)
     log_warn("Device not found for criteria: #{criteria.inspect}")
  end
end
