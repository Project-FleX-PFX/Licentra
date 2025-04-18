module LicenseTypeLogging
    def log_license_type_created(license_type)
      log_info("License Type created: #{license_type.inspect}")
    end
  
    def log_license_type_found(license_type)
      log_info("License Type found: #{license_type.inspect}")
    end
  
    def log_license_type_not_found(id)
      log_warn("License Type with ID #{id} not found")
    end
  
    def log_license_type_found_by_criteria(criteria, license_type)
      log_info("License Type found by #{criteria.inspect}: #{license_type.inspect}")
    end
  
    def log_license_type_found_by_name(name, license_type)
      log_info("License Type found by name '#{name}': #{license_type.inspect}")
    end
  
    def log_license_type_not_found_by_criteria(criteria)
      log_warn("License Type not found for criteria: #{criteria.inspect}")
    end
  
    def log_license_type_not_found_by_name(name)
      log_warn("License Type not found with name: '#{name}'")
    end
  
    def log_validation_failed(license_type, context)
      log_warn("Validation failed while #{context} license type: #{license_type.errors.inspect}")
    end
  
    def log_license_types_fetched(count)
      log_info("Fetched #{count} license types")
    end
  
    def log_license_types_fetched_with_criteria(count, criteria)
      log_info("Fetched #{count} license types with criteria: #{criteria.inspect}")
    end
  
    def log_license_type_updated(license_type)
      log_info("License Type updated: #{license_type.inspect}")
    end
  
    def log_license_type_deleted(license_type)
      log_info("License Type deleted: #{license_type.inspect}")
    end
  end
