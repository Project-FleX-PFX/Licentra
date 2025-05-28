# frozen_string_literal: true

require_relative '../dao/product_dao'
require_relative '../dao/security_log_dao'
require_relative '../models/user'

class ProductService
  class ServiceError < StandardError; end
  class ProductManagementError < ServiceError; end
  class NotFoundError < ServiceError; end
  class NotAuthorizedError < ServiceError; end

  def self.create_product_as_admin(params, admin_user)
    _authorize_admin(admin_user)

    product_name = params[:product_name]&.strip
    raise ProductManagementError, 'Product name is required.' if product_name.nil? || product_name.empty?

    if ProductDAO.find_by_name(product_name)
      raise ProductManagementError, "Product name '#{product_name}' already exists."
    end

    product_attributes = { product_name: product_name }
    new_product = ProductDAO.create(product_attributes) # Kann Sequel::ValidationFailed auslösen

    SecurityLogDAO.log_product_created(acting_user: admin_user, product: new_product)
    new_product
  rescue Sequel::ValidationFailed => e
    raise ProductManagementError, "Product creation failed: #{e.errors.full_messages.join(', ')}"
  rescue ProductManagementError => e
    raise e
  rescue NotAuthorizedError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in create_product_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ProductManagementError, 'An unexpected error occurred while creating the product.'
  end

  def self.update_product_as_admin(product_id, params, admin_user)
    _authorize_admin(admin_user)
    product_to_update = _find_product_or_fail(product_id)

    new_product_name = params[:product_name]&.strip

    raise ProductManagementError, 'Product name cannot be empty.' if new_product_name.nil? || new_product_name.empty?

    begin
      existing_product = ProductDAO.find_by_name!(new_product_name) # Löst DAO::RecordNotFound aus, wenn nicht gefunden
      if existing_product.product_id != product_to_update.product_id
        raise ProductManagementError, "Product name '#{new_product_name}' already exists."
      end
    rescue DAO::RecordNotFound
    end

    old_product_name = product_to_update.product_name

    if old_product_name == new_product_name
      changes_description = "Product '#{old_product_name}' (ID: #{product_id}) update attempted, but name was already '#{new_product_name}'"
      SecurityLogDAO.log_product_updated(
        acting_user: admin_user,
        product: product_to_update,
        changes_description: changes_description
      )
      return product_to_update
    end

    changes_description = "Product name changed from '#{old_product_name}' to '#{new_product_name}'"

    if product_to_update.update(product_name: new_product_name)
      SecurityLogDAO.log_product_updated(
        acting_user: admin_user,
        product: product_to_update,
        changes_description: changes_description
      )
      product_to_update
    else
      error_messages = product_to_update.errors&.full_messages&.join(', ') || 'Reason unknown.'
      raise ProductManagementError,
            "Failed to update product '#{old_product_name}' (ID: #{product_id}). #{error_messages}"
    end
  rescue Sequel::ValidationFailed => e # Wird von product_to_update.update ausgelöst
    raise ProductManagementError,
          "Product update failed for '#{old_product_name}' (ID: #{product_id}): #{e.errors.full_messages.join(', ')}"
  rescue ProductManagementError => e # Explizit hier oder in DAO ausgelöste Fehler
    raise e
  rescue NotFoundError => e # Von _find_product_or_fail
    raise e
  rescue NotAuthorizedError => e # Von _authorize_admin
    raise e
  rescue StandardError => e
    product_name_for_log = product_to_update ? "'#{product_to_update.product_name}' " : ''
    puts "ERROR: Unexpected error in update_product_as_admin for product #{product_name_for_log}(ID: #{product_id}): #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ProductManagementError,
          "An unexpected error occurred while updating product #{product_name_for_log}(ID: #{product_id})."
  end

  def self.delete_product_as_admin(product_id, admin_user)
    _authorize_admin(admin_user)
    product_to_delete = _find_product_or_fail(product_id)

    if LicenseDAO.where(product_id: product_id).any? # Diese Prüfung ist spezifisch für die Geschäftslogik
      raise ProductManagementError,
            "Cannot delete product '#{product_to_delete.product_name}' as it has associated licenses. Please delete them first."
    end

    ProductDAO.delete(product_id)

    SecurityLogDAO.log_product_deleted(
      acting_user: admin_user,
      deleted_product_name: product_to_delete.product_name,
      deleted_product_id: product_to_delete.product_id
    )
    true
  rescue ProductManagementError => e
    raise e
  rescue NotFoundError => e # Explizit abfangen
    raise e
  rescue NotAuthorizedError => e # Explizit abfangen
    raise e
  rescue StandardError => e
    product_name_for_log = product_to_delete ? "'#{product_to_delete.product_name}' " : ''
    puts "ERROR: Unexpected error in delete_product_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ProductManagementError,
          "An unexpected error occurred while deleting product #{product_name_for_log}(ID: #{product_id})."
  end

  def self._authorize_admin(user)
    raise NotAuthorizedError, 'Admin privileges required.' unless user&.admin?
  end

  def self._find_product_or_fail(product_id)
    ProductDAO.find!(product_id) # find! löst DAO::RecordNotFound, wenn nicht gefunden
  rescue DAO::RecordNotFound
    raise NotFoundError, "Product (ID: #{product_id}) not found." # In Service-eigenen Fehler umwandeln
  end
end
