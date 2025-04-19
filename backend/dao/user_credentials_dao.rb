require_relative '../models/user_credential'
require_relative 'base_dao'
require_relative 'user_credential_logging'
require_relative 'user_credential_error_handling'

class UserCredentialDAO < BaseDAO
  class << self
    include UserCredentialLogging
    include UserCredentialErrorHandling
   
    MODEL_PK = :user_id

    # CREATE
    def create(attributes)
      context = "creating user credential for user_id #{attributes[:user_id]}"
      with_error_handling(context) do
        credential = UserCredential.new(attributes)
        if credential.valid?
          credential.save
          log_credential_created(credential)
          credential
        else
          handle_validation_error(credential, context)
        end
      end
    end

    # READ
    def find!(user_id)
      with_error_handling("finding user credential for user_id #{user_id}") do
        credential = UserCredential[MODEL_PK => user_id]
        unless credential
          handle_record_not_found(user_id)
        end
        log_credential_found(credential)
        credential
      end
    end

    def find(user_id)
      with_error_handling("finding user credential for user_id #{user_id}") do
        credential = UserCredential[MODEL_PK => user_id]
        log_credential_found(credential) if credential
        credential
      end
    end

    # UPDATE
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
           log_validation_failed(credential, context)
           raise ValidationError.new("Validation failed: #{e.message}", { password: [e.message] }, credential)
        rescue Sequel::ValidationFailed => e
           handle_validation_error(e.model, context)
        end
      end
    end

    # DELETE
    def delete(user_id)
      with_error_handling("deleting user credential for user_id #{user_id}") do
        credential = find!(user_id)
        credential.destroy
        log_credential_deleted(credential)
        true
      end
    end

  end
end
