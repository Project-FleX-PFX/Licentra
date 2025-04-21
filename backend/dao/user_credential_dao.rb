# frozen_string_literal: true

require_relative '../models/user_credential'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'user_credential_logging'
require_relative 'user_credential_error_handling'

# Data Access Object for UserCredential entities, handling database operations
class UserCredentialDAO < BaseDAO
  def self.model_class
    UserCredential
  end

  def self.primary_key
    :user_id
  end

  include CrudOperations

  class << self
    include UserCredentialLogging
    include UserCredentialErrorHandling
  end

  class << self
    def update(id, attributes)
      raise NotImplementedError, 'Generic update is not supported for UserCredential. Use update_password.'
    end

    def update_password(user_id, new_plain_password)
      context = "updating password for user_id #{user_id}"
      with_error_handling(context) do
        credential = find!(user_id)

        begin
          credential.password_plain = new_plain_password
          credential.save_changes
          log_password_updated(credential)
          credential
        rescue ArgumentError => e
          handle_validation_error(credential, "#{context} - invalid input: #{e.message}")
        rescue Sequel::ValidationFailed => e
          handle_validation_error(e.model, context)
        end
      end
    end
  end
end
