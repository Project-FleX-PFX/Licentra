# frozen_string_literal: true

require_relative '../models/product'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'product_logging'
require_relative 'product_error_handling'

# Data Access Object for Product entities, handling database operations
class ProductDAO < BaseDAO
  def self.model_class
    Product
  end

  def self.primary_key
    :product_id
  end

  include CrudOperations

  class << self
    include ProductLogging
    include ProductErrorHandling
  end

  class << self
    def find_by_name(name)
      return nil if name.nil? || name.empty?

      product = find_one_by(product_name: name)
      log_product_found_by_name(name, product) if product
      product
    end

    def find_by_name!(name)
      find_by_name(name) || handle_record_not_found_by_name(name)
    end

    def delete(id)
      context = "deleting product with ID #{id}"
      with_error_handling(context) do
        product = find!(id)
        if product.licenses_dataset.any?
          raise ProductManagementError, "Cannot delete product #{id} because it still has associated licenses."
        end

        super(id)
      end
    end

  end
end
