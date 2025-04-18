require_relative '../models/license_type'
require_relative 'base_dao'
require_relative 'license_type_logging'
require_relative 'license_type_error_handling'

class LicenseTypeDAO < BaseDAO
  class << self
    include LicenseTypeLogging
    include LicenseTypeErrorHandling

    # CREATE
    def create(attributes)
      with_error_handling("creating license type") do
        license_type = LicenseType.new(attributes)
        if license_type.valid?
          license_type.save
          log_license_type_created(license_type)
          license_type
        else
          handle_validation_error(license_type, "creating license type")
        end
      end
    end

    # READ
    def find!(id)
      with_error_handling("finding license type with ID #{id}") do
        license_type = LicenseType[id]
        unless license_type
          handle_record_not_found(id)
        end
        log_license_type_found(license_type)
        license_type
      end
    end

    def find(id)
      with_error_handling("finding license type with ID #{id}") do
        license_type = LicenseType[id]
        log_license_type_found(license_type) if license_type
        license_type
      end
    end

    def find_one_by(criteria)
      with_error_handling("finding license type by criteria") do
        license_type = LicenseType.first(criteria)
        log_license_type_found_by_criteria(criteria, license_type) if license_type
        license_type
      end
    end

    def find_one_by!(criteria)
      with_error_handling("finding license type by criteria") do
        license_type = find_one_by(criteria)
        unless license_type
          handle_record_not_found_by_criteria(criteria)
        end
        license_type
      end
    end

    # Specific finder based on unique type_name
    def find_by_name(name)
      return nil if name.nil? || name.empty?
      license_type = find_one_by(type_name: name)
      log_license_type_found_by_name(name, license_type) if license_type
      license_type
    end

    def find_by_name!(name)
       with_error_handling("finding license type by name '#{name}'") do
         license_type = find_by_name(name)
         unless license_type
           handle_record_not_found_by_name(name)
         end
         license_type
       end
    end

    def all(options = {})
      with_error_handling("fetching all license types") do
        dataset = LicenseType.dataset
        dataset = dataset.where(options[:where]) if options[:where]
        dataset = dataset.order(options[:order]) if options[:order]
        license_types = dataset.all
        log_license_types_fetched(license_types.size)
        license_types
      end
    end

    def where(criteria)
      with_error_handling("filtering license types by criteria") do
        license_types = LicenseType.where(criteria).all
        log_license_types_fetched_with_criteria(license_types.size, criteria)
        license_types
      end
    end

    # UPDATE
    def update(id, attributes)
      with_error_handling("updating license type with ID #{id}") do
        license_type = find!(id)
        license_type.update(attributes)
        log_license_type_updated(license_type)
        license_type
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, "updating license type with ID #{id}")
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting license type with ID #{id}") do
        license_type = find!(id)
        if license_type.licenses_dataset.any?
          raise DatabaseError, "Cannot delete license type '#{license_type.type_name}' (ID: #{id}) because it is still referenced by licenses."
        end
        license_type.destroy
        log_license_type_deleted(license_type)
        true
      end
    end

  end
end
