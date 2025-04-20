module DeviceErrorHandling
  def handle_validation_error(device, context)
    log_validation_failed(device, context)
    raise DAO::ValidationError.new("Validation failed while #{context}", device.errors, device)
  end

  def handle_record_not_found(id)
    log_record_not_found(id)
    raise DAO::RecordNotFound, "Device with ID #{id} not found"
  end

  def handle_record_not_found_by_criteria(criteria)
    log_record_not_found_by_criteria(criteria)
    raise DAO::RecordNotFound, "Device not found for criteria: #{criteria.inspect}"
  end
end

