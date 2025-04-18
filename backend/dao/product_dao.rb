require_relative '../models/product'
require_relative 'base_dao'
require_relative 'product_logging'
require_relative 'product_error_handling'

class ProductDAO < BaseDAO
  class << self
    include ProductLogging
    include ProductErrorHandling

    # CREATE
    def create(attributes)
      with_error_handling("creating product") do
        product = Product.new(attributes)
        if product.valid?
          product.save
          log_product_created(product)
          product
        else
          handle_validation_error(product, "creating product")
        end
      end
    end

    # READ
    def find!(id)
      with_error_handling("finding product with ID #{id}") do
        product = Product[id]
        unless product
          handle_record_not_found(id)
        end
        log_product_found(product)
        product
      end
    end

    def find(id)
      with_error_handling("finding product with ID #{id}") do
        product = Product[id]
        log_product_found(product) if product
        product
      end
    end

    def find_one_by(criteria)
      with_error_handling("finding product by criteria") do
        product = Product.first(criteria)
        log_product_found_by_criteria(criteria, product) if product
        product
      end
    end

    def find_one_by!(criteria)
      with_error_handling("finding product by criteria") do
        product = find_one_by(criteria)
        unless product
          handle_record_not_found_by_criteria(criteria)
        end
        product
      end
    end

    def find_by_name(name)
      return nil if name.nil? || name.empty?
      product = find_one_by(product_name: name)
      log_product_found_by_name(name, product) if product
      product
    end

    def find_by_name!(name)
      with_error_handling("finding product by name '#{name}'") do
        product = find_by_name(name)
        unless product
           handle_record_not_found_by_name(name)
        end
        product
      end
    end

    def all(options = {})
      with_error_handling("fetching all products") do
        dataset = Product.dataset
        dataset = dataset.where(options[:where]) if options[:where]
        dataset = dataset.order(options[:order]) if options[:order]
        products = dataset.all
        log_products_fetched(products.size)
        products
      end
    end

    def where(criteria)
      with_error_handling("filtering products by criteria") do
        products = Product.where(criteria).all
        log_products_fetched_with_criteria(products.size, criteria)
        products
      end
    end

    # UPDATE
    def update(id, attributes)
      with_error_handling("updating product with ID #{id}") do
        product = find!(id)
        product.update(attributes)
        log_product_updated(product)
        product
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, "updating product with ID #{id}")
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting product with ID #{id}") do
        product = find!(id)
        if product.licenses_dataset.any?
          raise DatabaseError, "Cannot delete product #{id} because it still has associated licenses."
        end
        product.destroy
        log_product_deleted(product)
        true
      end
    end

  end
end
