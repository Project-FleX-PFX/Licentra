# frozen_string_literal: true

require_relative '../models/license'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'license_logging'
require_relative 'license_error_handling'

# Data Access Object for License entities, handling database operations
class LicenseDAO < BaseDAO
  def self.model_class
    License
  end

  def self.primary_key
    :license_id
  end

  include CrudOperations

  class << self
    include LicenseLogging
    include LicenseErrorHandling
  end

  class << self
    def find_by_product(product_id)
      context = "finding licenses for product ID #{product_id}"
      with_error_handling(context) do
        licenses = where(product_id: product_id)
        log_licenses_for_product_fetched(product_id, licenses.size)
        licenses
      end
    end

    def find_by_license_type(license_type_id)
      context = "finding licenses for type ID #{license_type_id}"
      with_error_handling(context) do
        licenses = where(license_type_id: license_type_id)
        log_licenses_for_type_fetched(license_type_id, licenses.size)
        licenses
      end
    end

    def delete(id)
      context = "deleting license with ID #{id}"
      with_error_handling(context) do
        find!(id)
        active_assignments = DB[:license_assignments].where(license_id: id, is_active: true).count
        if active_assignments.positive?
          raise DatabaseError, "Cannot delete license ID #{id}: #{active_assignments} active assignments exist."
        end

        super(id)
      end
    end

    def find_available_for_assignment
      licenses_with_potential = model_class.where(status: 'Active').where { seat_count > 0 }.all
      licenses_with_potential.select { |lic| lic.available_seats > 0 }
    end
  end
end
