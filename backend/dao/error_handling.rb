# frozen_string_literal: true

require_relative 'logger'

# Provides error handling functionality for all DAO operations
module DaoErrorHandling
  def with_error_handling(context)
    yield
  rescue ::DAO::ValidationError, ::DAO::RecordNotFound, ::DAO::DatabaseError => e
    raise
  rescue Sequel::ValidationFailed => e
    DaoLogger.log_error("Validation error while #{context}: #{e.message}")
    raise ::DAO::ValidationError.new("Validation error while #{context}: #{e.message}", e.errors, e.model)
  rescue Sequel::NoMatchingRow => e
    DaoLogger.log_error("Record not found while #{context}: #{e.message}")
    raise ::DAO::RecordNotFound, "Record not found while #{context}: #{e.message}"
  rescue Sequel::DatabaseError => e
    DaoLogger.log_error("Database error while #{context}: #{e.message}")
    raise ::DAO::DatabaseError, "Database error while #{context}: #{e.message}"
  rescue Sequel::Error => e
    DaoLogger.log_error("Sequel error while #{context}: #{e.message}")
    raise ::DAO::DatabaseError, "Sequel error while #{context}: #{e.message}"
  rescue StandardError => e
    original_message = e.message
    DaoLogger.log_error("An unexpected standard error occurred while #{context}: #{e.class} - #{original_message}\n#{e.backtrace.first(5).join("\n")}")
    raise ::DAO::DAOError, "An unexpected error occurred while #{context}: #{original_message}"
  end
end
