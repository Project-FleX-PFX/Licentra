# frozen_string_literal: true

require_relative '../dao/product_dao'
require_relative '../dao/security_log_dao'
require_relative '../models/user'

class ProductService
  class ServiceError < StandardError; end
  class ProductManagementError < ServiceError; end
  class NotFoundError < ServiceError; end

  def self.create_product_as_admin(params, admin_user)
    _authorize_admin(admin_user)

    product_attributes = {
      product_name: params[:product_name]&.strip
    }
    # Basisvalidierung
    if product_attributes[:product_name].nil? || product_attributes[:product_name].empty?
      raise ProductManagementError,
            'Product name is required.'
    end

    new_product = ProductDAO.create(product_attributes)
    raise ProductManagementError, 'Failed to create product.' unless new_product

    SecurityLogDAO.log_product_created(acting_user: admin_user, product: new_product)
    new_product
  rescue Sequel::ValidationFailed => e
    raise ProductManagementError, "Product creation failed: #{e.errors.full_messages.join(', ')}"
  rescue StandardError => e
    puts "ERROR: Unexpected error in create_product_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ProductManagementError, 'An unexpected error occurred while creating the product.'
  end

  def self.update_product_as_admin(product_id, params, admin_user)
    _authorize_admin(admin_user)
    product_to_update = _find_product_or_fail(product_id)

    new_product_name = params[:product_name]&.strip

    raise ProductManagementError, 'Product name cannot be empty.' if new_product_name.nil? || new_product_name.empty?

    if ProductDAO.find_by_name(new_product_name)
      raise ProductManagementError, "Product name '#{new_product_name}' already exists."
    end

    old_product_name = product_to_update.product_name
    changes_description = "Product name changed from '#{old_product_name}' to '#{new_product_name}'"

    updated_product = ProductDAO.update(product_id, product_name: new_product_name)

    if updated_product
      SecurityLogDAO.log_product_updated(
        acting_user: admin_user,
        product: updated_product,
        changes_description: changes_description
      )
      updated_product
    else
      raise ProductManagementError,
            "Failed to update product #{product_id}. #{product_to_update.errors.full_messages.join(', ')}"
    end
  rescue Sequel::ValidationFailed => e
    raise ProductManagementError, "Product update failed: #{e.errors.full_messages.join(', ')}"
  rescue StandardError => e
    puts "ERROR: Unexpected error in update_product_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ProductManagementError, 'An unexpected error occurred while updating the product.'
  end

  def self.delete_product_as_admin(product_id, admin_user)
    _authorize_admin(admin_user)
    product_to_delete = _find_product_or_fail(product_id) # Für Logging

    # Überlegung: Was passiert mit Lizenzen, die zu diesem Produkt gehören?
    # Hier gehen wir davon aus, dass das Löschen eines Produkts fehlschlägt, wenn Lizenzen existieren.
    # Alternativ: Lizenzen löschen oder Produkt als "archiviert" markieren.
    if LicenseDAO.where(product_id: product_id).any?
      raise ProductManagementError,
            "Cannot delete product '#{product_to_delete.product_name}' as it has associated licenses. Please delete them first."
    end

    raise ProductManagementError, "Failed to delete product #{product_id}." unless ProductDAO.delete(product_id)

    SecurityLogDAO.log_product_deleted(
      acting_user: admin_user,
      deleted_product_name: product_to_delete.product_name,
      deleted_product_id: product_to_delete.product_id
    )
    true
  rescue ProductManagementError => e
    raise e # Re-raise specific errors
  rescue StandardError => e
    puts "ERROR: Unexpected error in delete_product_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ProductManagementError, 'An unexpected error occurred while deleting the product.'
  end

  private_class_method

  def self._authorize_admin(user)
    raise NotAuthorizedError, 'Admin privileges required.' unless user.admin?
  end

  def self._find_product_or_fail(product_id)
    ProductDAO.find!(product_id)
  rescue DAO::RecordNotFound
    raise NotFoundError, "Product (ID: #{product_id}) not found."
  end
end
