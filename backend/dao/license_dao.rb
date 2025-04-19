require_relative '../models/license'
require_relative 'base_dao'
require_relative 'license_logging'
require_relative 'license_error_handling'

class LicenseDAO < BaseDAO
  class << self
    include LicenseLogging
    include LicenseErrorHandling

    MODEL_PK = :id

    # CREATE
    def create(attributes)
      context = "creating license"
      with_error_handling(context) do
        license = License.new(attributes)
        if license.valid?
          license.save
          log_license_created(license)
          license
        else
          handle_validation_error(license, context)
        end
      end
    end

    # READ
    def find!(id)
      with_error_handling("finding license with ID #{id}") do
        license = License.eager(:product, :license_type)[id]
        unless license
          handle_record_not_found(id)
        end
        log_license_found(license)
        license
      end
    end

    def find(id)
      with_error_handling("finding license with ID #{id}") do
        license = License.eager(:product, :license_type)[id]
        log_license_found(license) if license
        license
      end
    end

    def find_one_by(criteria)
      with_error_handling("finding license by criteria") do
        license = License.eager(:product, :license_type).first(criteria)
        log_license_found_by_criteria(criteria, license) if license
        license
      end
    end

    def find_one_by!(criteria)
      with_error_handling("finding license by criteria") do
        license = find_one_by(criteria)
        unless license
          handle_record_not_found_by_criteria(criteria)
        end
        license
      end
    end

    def all(options = {})
      with_error_handling("fetching all licenses") do
        dataset = License.dataset
        dataset = dataset.where(options[:where]) if options[:where]
        dataset = dataset.order(options[:order]) if options[:order]
        dataset = dataset.eager(:product, :license_type) if options[:eager_relations]
        licenses = dataset.all
        log_licenses_fetched(licenses.size)
        licenses
      end
    end

    def where(criteria)
      with_error_handling("filtering licenses by criteria") do
        licenses = License.eager(:product, :license_type).where(criteria).all
        log_licenses_fetched_with_criteria(licenses.size, criteria)
        licenses
      end
    end

    # UPDATE
    def update(id, attributes)
      context = "updating license with ID #{id}"
      with_error_handling(context) do
        license = find!(id)
        license.update(attributes)
        log_license_updated(license)
        license
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, context)
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting license with ID #{id}") do
        license = find!(id)

        if license.license_assignments_dataset.where(is_active: true).any?
           raise DatabaseError, "Cannot delete license ID #{id}: Active assignments exist."
        end

        license.destroy
        log_license_deleted(license)
        true
      end
    end

    # --- SPECIAL QUERIES ---
    def find_by_product(product_id)
      context = "finding licenses for product ID #{product_id}"
      with_error_handling(context) do
         licenses = where(product_id: product_id)
         log_licenses_for_product_fetched(product_id, licenses.size)
         licenses
      end
    end

    def find_by_license_type(license_type_id)
       with_error_handling("finding licenses for type ID #{license_type_id}") do
         where(license_type_id: license_type_id)
       end
    end

    def find_with_available_seats(options = {})
       licenses = all(options)
       available = licenses.select { |l| l.available_seats > 0 }
       available
    end

  end
end
