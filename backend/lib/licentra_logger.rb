# frozen_string_literal: true

require 'logger'

# Main namespace for the Licentra license management system
# Contains core functionality and utilities used throughout the application
module Licentra
  class << self
    # By default, logs are written to STDOUT (the console).
    # To log to a file instead, change '$stdout' to a file path, e.g. 'log/licentra.log'.
    def logger
      @logger ||= Logger.new(log_output, level: log_level, progname: 'Licentra')
    end

    private

    def log_output
      ENV.fetch('LICENTRA_LOG_OUTPUT', '$stdout') == '$stdout' ? $stdout : ENV.fetch('LICENTRA_LOG_OUTPUT', nil)
    end

    def log_level
      level = ENV.fetch('LICENTRA_LOG_LEVEL', 'INFO').upcase
      case level
      when 'DEBUG' then Logger::DEBUG
      when 'INFO'  then Logger::INFO
      when 'WARN'  then Logger::WARN
      when 'ERROR' then Logger::ERROR
      when 'FATAL' then Logger::FATAL
      else Logger::INFO
      end
    end
  end
end
