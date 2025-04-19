require_relative '../models/license_type'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'license_type_logging'
require_relative 'license_type_error_handling'

class LicenseTypeDAO < BaseDAO

  def self.model_class
    LicenseType
  end

  def self.primary_key
    :license_type_id
  end

  include CrudOperations

  class << self
    include LicenseTypeLogging
    include LicenseTypeErrorHandling
  end

  class << self

    def find_by_name(name)
      return nil if name.nil? || name.empty?
      license_type = find_one_by(type_name: name)
      log_license_type_found_by_name(name, license_type) if license_type
      license_type
    end

    def find_by_name!(name)
       find_by_name(name) || handle_record_not_found_by_name(name)
    end

    def delete(id)
      context = "deleting license type with ID #{id}"
      with_error_handling(context) do
        license_type = find!(id)
        if license_type.licenses_dataset.any?
          raise DatabaseError, "Cannot delete..."
        end
        super(id)
      end
    end

  end
end
