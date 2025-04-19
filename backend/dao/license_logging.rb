module LicenseLogging
    def log_license_created(license)
      log_info("License created: ID #{license.pk}, Product ID #{license.product_id}, Type ID #{license.license_type_id}, Seats #{license.seat_count}")
    end
  
    def log_license_found(license)
      log_info("License found: ID #{license.pk}")
    end
  
    def log_license_not_found(id)
      log_warn("License with ID #{id} not found")
    end
  
    def log_license_found_by_criteria(criteria, license)
      log_info("License found by #{criteria.inspect}: ID #{license.pk}")
    end
  
    def log_license_not_found_by_criteria(criteria)
      log_warn("License not found for criteria: #{criteria.inspect}")
    end
  
    def log_validation_failed(license, context)
      log_warn("Validation failed while #{context} license (ID: #{license.pk || 'new'}): #{license.errors.inspect}")
    end
  
    def log_licenses_fetched(count)
      log_info("Fetched #{count} licenses")
    end
  
    def log_licenses_fetched_with_criteria(count, criteria)
      log_info("Fetched #{count} licenses with criteria: #{criteria.inspect}")
    end
  
    def log_license_updated(license)
      log_info("License updated: ID #{license.pk}")
    end
  
    def log_license_deleted(license)
      log_info("License deleted: ID #{license.pk}")
    end
  
    def log_licenses_for_product_fetched(product_id, count)
      log_info("Fetched #{count} licenses for Product ID #{product_id}")
    end
end
