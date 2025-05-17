# frozen_string_literal: true

require_relative 'logger'
require_relative 'error_handling'
require_relative 'errors'

# Base Data Access Object class that provides common functionality for all DAOs
class BaseDAO
  class << self
    include DaoErrorHandling

    # common logging methods
    def log_info(message)
      DaoLogger.log_info(message)
    end

    def log_warn(message)
      DaoLogger.log_warn(message)
    end

    def log_error(message)
      DaoLogger.log_error(message)
    end

    private

    def _parse_date(date_param)
      return nil if date_param.nil? || (date_param.is_a?(String) && date_param.strip.empty?)
      return date_param.to_date if date_param.is_a?(Date) || date_param.is_a?(Time) || date_param.is_a?(DateTime)

      if date_param.is_a?(String)
        begin
          return Date.parse(date_param)
        rescue ArgumentError, TypeError
          log_warn("Invalid date string received for filter: '#{date_param}'")
          return nil
        end
      end
      log_warn("Unsupported date type received for filter: #{date_param.class}")
      nil
    end
  end
end
