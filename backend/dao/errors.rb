module DAO

  class DAOError < StandardError; end

  class RecordNotFound < DAOError; end

  class ValidationError < DAOError
    attr_reader :errors, :model
    def initialize(message = "Validation failed", errors = {}, model = nil)
      super(message)
      @errors = errors
      @model = model
    end
  end

  class DatabaseError < DAOError; end

end
