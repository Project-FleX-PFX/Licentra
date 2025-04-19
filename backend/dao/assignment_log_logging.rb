module AssignmentLogLogging
    def log_log_created(log)
      log_info("Assignment Log created: ID #{log.pk}, Assignment ID #{log.assignment_id}, Action: #{log.action}, Time: #{log.log_timestamp}")
    end
  
    def log_log_found(log)
      log_info("Assignment Log found: ID #{log.pk}")
    end
  
    def log_log_not_found(id)
      log_warn("Assignment Log with ID #{id} not found")
    end
  
    def log_log_found_by_criteria(criteria, log)
      log_info("Assignment Log found by #{criteria.inspect}: ID #{log.pk}")
    end
  
    def log_log_not_found_by_criteria(criteria)
      log_warn("Assignment Log not found for criteria: #{criteria.inspect}")
    end
  
    def log_validation_failed(log, context)
      log_warn("Validation failed while #{context} assignment log (ID: #{log.pk || 'new'}, Assignment: #{log.assignment_id}): #{log.errors.inspect}")
    end
  
    def log_logs_fetched(count)
      log_info("Fetched #{count} assignment logs")
    end
  
    def log_logs_fetched_with_criteria(count, criteria)
      log_info("Fetched #{count} assignment logs with criteria: #{criteria.inspect}")
    end
  
    def log_log_updated(log)
      log_info("Assignment Log updated: ID #{log.pk}")
    end
  
    def log_log_deleted(log)
      log_info("Assignment Log deleted: ID #{log.pk}")
    end
  
    def log_logs_for_assignment_fetched(assignment_id, count)
       log_info("Fetched #{count} logs for Assignment ID #{assignment_id}")
    end
end
