# frozen_string_literal: true

module DAO
  class DAOError < StandardError; end

  class RecordNotFound < DAOError; end

  # Represents validation errors that occur during DAO operations
  class ValidationError < DAOError
    attr_reader :errors, :model

    def initialize(message = 'Validation failed', errors = {}, model = nil)
      super(message)
      @errors = errors
      @model = model
    end
  end

  class DatabaseError < DAOError; end

  class AdminProtectionError < DAOError; end
end
