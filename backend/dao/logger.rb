require_relative '../lib/logger'

module DaoLogger
  class << self
    def log_info(message)
      Licentra.logger.info(message)
    end

    def log_warn(message)
      Licentra.logger.warn(message)
    end

    def log_error(message)
      Licentra.logger.error(message)
    end
  end
end

