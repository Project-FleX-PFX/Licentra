module DaoErrorHandling
  
  def with_error_handling(context)
    yield
  rescue Sequel::ValidationFailed => e
    DaoLogger.log_error("Validation error while #{context}: #{e.message}")
    raise ValidationError.new(e.message, e.errors, e.model)
  rescue Sequel::DatabaseError => e
    DaoLogger.log_error("Database error while #{context}: #{e.message}")
    raise DatabaseError, "Database error while #{context}: #{e.message}"
  rescue Sequel::Error => e
    DaoLogger.log_error("Sequel error while #{context}: #{e.message}")
    raise DatabaseError, "Sequel error while #{context}: #{e.message}"
  rescue => e
    DaoLogger.log_error("Unknown error while #{context}: #{e.message}")
    raise
  end

end
