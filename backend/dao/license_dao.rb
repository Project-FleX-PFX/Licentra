# frozen_string_literal: true

require_relative '../models/license'
require_relative '../models/product'
require_relative 'base_dao'
require_relative 'license_assignment_dao'
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
    def all_with_details(options = {})
      context = 'fetching all licenses with their associated products'
      with_error_handling(context) do
        dataset = model_class.dataset

        order_criteria = options[:order] || [Sequel.asc(Sequel[:products][:product_name]),
                                             Sequel.asc(Sequel[:licenses][:license_name])]
        order_criteria = Array(order_criteria)

        dataset = dataset.left_join(:products, product_id: :product_id)
                         .select_all(:licenses)
                         .order(*order_criteria)
                         .eager(:product)

        licenses_with_product = dataset.all

        log_info("Fetched #{licenses_with_product.size} licenses with product details.")
        licenses_with_product
      end
    end

    def find_with_details!(id)
      context = "finding license ID #{id} with product details"
      with_error_handling(context) do
        license_with_product = model_class
                               .dataset
                               .where(Sequel[:licenses][:license_id] => id)
                               .eager(:product)
                               .first

        raise DAO::RecordNotFound, "License (ID: #{id}) not found." unless license_with_product

        log_license_fetched_with_details(license_with_product)
        license_with_product
      end
    end

    def find_with_details(id)
      find_with_details!(id)
    rescue DAO::RecordNotFound
      nil
    end

    def delete(id)
      context = "deleting license with ID #{id}"
      with_error_handling(context) do
        license = find_with_details!(id)
        active_assignments = DB[:license_assignments].where(license_id: id, is_active: true).count
        if active_assignments.positive?
          raise LicenseManagementError,
                "Cannot delete license '#{license.license_name}' (ID: #{id}): #{active_assignments} active assignments exist."
        end

        deleted_count = model_class.where(primary_key => id).delete
        raise DAO::RecordNotFound, "License (ID: #{id}) could not be deleted or was not found." if deleted_count.zero?

        log_license_deleted(license)
        true
      end
    end

    def find_by_product(product_id)
      context = "finding licenses for product ID #{product_id}"
      with_error_handling(context) do
        licenses = where(product_id: product_id)
        log_licenses_for_product_fetched(product_id, licenses.size)
        licenses
      end
    end

    def count_by_product(product_id)
      context = "counting licenses for product ID #{product_id}"
      with_error_handling(context) do
        count = where(product_id: product_id).count
        log_licenses_for_product_fetched(product_id, count)
        count
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

    def find_available_for_assignment
      licenses_with_potential = model_class.where(Sequel.lit('expire_date IS NULL OR expire_date >= ?', Date.today))
                                           .all
      licenses_with_potential.select { |lic| lic.available_seats.positive? }
    end

    def find_available_for_user_assignment(user_id)
      context = "finding available licenses for assignment to user ID #{user_id}"
      with_error_handling(context) do
        assigned_license_ids_for_user = LicenseAssignmentDAO.model_class
                                                            .where(user_id: user_id)
                                                            .select_map(:license_id)
                                                            .uniq

        candidate_licenses = model_class.dataset
                                        .left_join(:products, product_id: :product_id)
                                        .where(Sequel.lit('licenses.expire_date IS NULL OR licenses.expire_date >= ?',
                                                          Date.today))
                                        .select_all(:licenses)
                                        .select_append(Sequel[:products][:product_name].as(:product_name))

        available = candidate_licenses.all.select do |lic|
          lic.available_seats.positive? && !assigned_license_ids_for_user.include?(lic.license_id)
        end
        log_info("Found #{available.size} licenses available for user ID #{user_id}.")
        available
      end
    end
  end
end
