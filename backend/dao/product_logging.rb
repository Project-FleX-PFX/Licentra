# frozen_string_literal: true

# Logging functionality specific to Product operations
module ProductLogging
  def log_created(product)
    log_info("Product created: #{product.inspect}")
  end

  def log_found(product)
    log_info("Product found: #{product.inspect}")
  end

  def log_found_by_criteria(criteria, product)
    log_info("Product found by #{criteria.inspect}: #{product.inspect}")
  end

  def log_fetched(count)
    log_info("Fetched #{count} products")
  end

  def log_fetched_with_criteria(count, criteria)
    log_info("Fetched #{count} products with criteria: #{criteria.inspect}")
  end

  def log_updated(product)
    log_info("Product updated: #{product.inspect}")
  end

  def log_deleted(product)
    log_info("Product deleted: #{product.inspect}")
  end

  def log_validation_failed(product, context)
    log_warn("Validation failed while #{context} product: #{product.errors.inspect}")
  end

  def log_record_not_found(id)
    log_warn("Product with ID #{id} not found")
  end

  def log_record_not_found_by_criteria(criteria)
    log_warn("Product not found for criteria: #{criteria.inspect}")
  end

  def log_record_not_found_by_name(name)
    log_warn("Product not found with name: '#{name}'")
  end

  def log_product_found_by_name(name, product)
    log_info("Product found by name '#{name}': #{product.inspect}")
  end
end
