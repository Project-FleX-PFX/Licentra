require_relative 'logger'
require_relative 'error_handling'
require_relative 'errors'

class BaseDAO
  class << self
    include DaoErrorHandling  # Änderung von extend zu include

    # Gemeinsame Logging-Methoden
    def log_info(message)
      DaoLogger.log_info(message)
    end

    def log_warn(message)
      DaoLogger.log_warn(message)
    end

    def log_error(message)
      DaoLogger.log_error(message)
    end
  end
end

