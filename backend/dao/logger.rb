# frozen_string_literal: true

require_relative '../lib/licentra_logger'

# Provides logging functionality for all DAO operations
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
