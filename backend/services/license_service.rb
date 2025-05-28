# frozen_string_literal: true

require_relative '../dao/license_dao'
require_relative '../dao/license_assignment_dao'
require_relative '../dao/assignment_log_dao'
require_relative '../dao/security_log_dao'
require_relative '../models/user'
require_relative '../models/license'
require_relative '../models/license_assignment'

# Service class which handles license assignments
class LicenseService
  # Custom Error Classes
  class ServiceError < StandardError; end
  class NotAvailableError < ServiceError; end
  class AlreadyAssignedError < ServiceError; end
  class NotAuthorizedError < ServiceError; end
  class NotFoundError < ServiceError; end
  class LicenseManagementError < ServiceError; end

  ALLOWED_CURRENCIES = %w[EUR USD].freeze

  # === Public Interface ===

  def self.create_license_as_admin(params, admin_user)
    _authorize_admin(admin_user)

    currency_param = params[:currency]&.strip&.upcase
    if !(currency_param.nil? || currency_param.empty?) && !ALLOWED_CURRENCIES.include?(currency_param)
      raise LicenseManagementError, "Invalid currency. Allowed values are: #{ALLOWED_CURRENCIES.join(', ')}."
    end

    license_attributes = {
      product_id: params[:product_id].to_i,
      license_type_id: params[:license_type_id].to_i,
      license_name: params[:license_name]&.strip,
      license_key: params[:license_key]&.strip,
      seat_count: params[:seat_count].to_i,
      purchase_date: if params[:purchase_date] && params[:purchase_date].empty?
                       nil
                     else
                       begin
                         Date.parse(params[:purchase_date])
                       rescue StandardError
                         nil
                       end
                     end,
      expire_date: if params[:expire_date] && params[:expire_date].empty?
                     nil
                   else
                     begin
                       Date.parse(params[:expire_date])
                     rescue StandardError
                       nil
                     end
                   end,
      cost: if params[:cost] && params[:cost].empty?
              nil
            else
              begin
                BigDecimal(params[:cost])
              rescue StandardError
                nil
              end
            end,
      currency: currency_param,
      vendor: params[:vendor]&.strip,
      notes: params[:notes]&.strip
    }
    license_attributes.compact!

    new_license = LicenseDAO.create(license_attributes)
    raise LicenseManagementError, 'Failed to create license.' unless new_license

    SecurityLogDAO.log_license_created(acting_user: admin_user, license: new_license)
    new_license
  rescue Sequel::ValidationFailed => e
    raise LicenseManagementError, "License creation failed: #{e.errors.full_messages.join(', ')}"
  rescue StandardError => e
    puts "ERROR: Unexpected error in create_license_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise LicenseManagementError, 'An unexpected error occurred while creating the license.'
  end

  def self.update_license_as_admin(license_id, params_from_route, admin_user)
    _authorize_admin(admin_user)
    license_to_update = _find_license_or_fail(license_id)

    update_attrs = {}
    update_attrs[:license_name] = params_from_route['license_name']&.strip if params_from_route.key?('license_name')
    update_attrs[:license_key] = params_from_route['license_key']&.strip if params_from_route.key?('license_key')
    if params_from_route.key?('seat_count') && !params_from_route['seat_count'].to_s.strip.empty?
      update_attrs[:seat_count] = params_from_route['seat_count'].to_i
    end
    if params_from_route.key?('product_id') && !params_from_route['product_id'].to_s.strip.empty?
      update_attrs[:product_id] = params_from_route['product_id'].to_i
    end
    if params_from_route.key?('license_type_id') && !params_from_route['license_type_id'].to_s.strip.empty?
      update_attrs[:license_type_id] = params_from_route['license_type_id'].to_i
    end
    if params_from_route.key?('purchase_date')
      date_str = params_from_route['purchase_date']
      update_attrs[:purchase_date] = if date_str.nil? || date_str.empty?
                                       nil
                                     else
                                       begin
                                         Date.parse(date_str)
                                       rescue StandardError
                                         nil
                                       end
                                     end
    end
    if params_from_route.key?('expire_date')
      date_str = params_from_route['expire_date']
      update_attrs[:expire_date] = if date_str.nil? || date_str.empty?
                                     nil
                                   else
                                     begin
                                       Date.parse(date_str)
                                     rescue StandardError
                                       nil
                                     end
                                   end
    end

    if params_from_route.key?('currency')
      currency_param = params_from_route['currency']&.strip&.upcase
      if !(currency_param.nil? || currency_param.empty?) && !ALLOWED_CURRENCIES.include?(currency_param)
        raise LicenseManagementError, "Invalid currency. Allowed values are: #{ALLOWED_CURRENCIES.join(', ')}."
      end

      update_attrs[:currency] = currency_param && currency_param.empty? ? nil : currency_param
    end

    if params_from_route.key?('cost')
      cost_str = params_from_route['cost'].to_s.strip
      update_attrs[:cost] = if cost_str.empty?
                              nil
                            else
                              begin
                                BigDecimal(cost_str)
                              rescue StandardError
                                nil
                              end
                            end
    end

    update_attrs[:vendor] = params_from_route['vendor']&.strip if params_from_route.key?('vendor')
    update_attrs[:notes] = params_from_route['notes']&.strip if params_from_route.key?('notes')

    update_attrs.compact!

    return license_to_update if update_attrs.empty?

    changes_descriptions = []
    update_attrs.each do |key, new_value|
      old_value = license_to_update.send(key)
      if old_value.to_s != new_value.to_s
        formatted_key = key.to_s.split('_').map(&:capitalize).join(' ')
        changes_descriptions << "#{formatted_key} changed from '#{old_value}' to '#{new_value}'"
      end
    end
    changes_description = changes_descriptions.empty? ? 'details updated (no specific changes logged)' : changes_descriptions.join('; ')

    updated_license_object = LicenseDAO.update(license_id, update_attrs)

    if updated_license_object
      puts "LicenseDAO.update returned: #{updated_license_object.inspect}"
      puts "Updated license name in object: #{updated_license_object.license_name}"
      SecurityLogDAO.log_license_updated(
        acting_user: admin_user,
        license: updated_license_object,
        changes_description: changes_description
      )
      updated_license_object
    else
      error_msg_from_model = ''
      if license_to_update.respond_to?(:errors) && license_to_update.errors&.any?
        error_msg_from_model = license_to_update.errors.full_messages.join(', ')
      end
      raise LicenseManagementError, "Failed to update license #{license_id}. #{error_msg_from_model}".strip
    end
  rescue Sequel::ValidationFailed => e
    raise LicenseManagementError, "License update failed due to validation: #{e.errors.full_messages.join(', ')}"
  rescue ArgumentError => e
    raise LicenseManagementError, "Invalid data format for update: #{e.message}"
  rescue LicenseService::NotFoundError
    raise
  rescue StandardError => e
    puts "ERROR: Unexpected error in LicenseService.update_license_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise LicenseManagementError, 'An unexpected error occurred while updating the license.'
  end

  def self.delete_license_as_admin(license_id, admin_user)
    _authorize_admin(admin_user)
    license_to_delete = _find_license_or_fail(license_id)

    if LicenseAssignmentDAO.where(license_id: license_id, is_active: true).any?
      raise LicenseManagementError,
            "Cannot delete license '#{license_to_delete.license_name}' as it has active assignments. Please deactivate them first."
    end

    begin
      DB.transaction do
        LicenseAssignmentDAO.model_class.where(license_id: license_id).delete

        if LicenseDAO.delete(license_id)
          SecurityLogDAO.log_license_deleted(
            acting_user: admin_user,
            deleted_license_name: license_to_delete.license_name,
            deleted_license_id: license_to_delete.license_id
          )
          return true
        else
          raise LicenseManagementError,
                "Failed to delete license (ID: #{license_id}) itself, though it might have existed."
        end
      end
    rescue Sequel::DatabaseError => e
      puts "ERROR: Database error during license deletion transaction for license_id #{license_id}: #{e.message}"
      raise LicenseManagementError,
            "A database error occurred while deleting the license and its assignments: #{e.message}"
    rescue LicenseManagementError => e
      raise e
    rescue StandardError => e
      puts "ERROR: Unexpected error in delete_license_as_admin for license_id #{license_id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      raise LicenseManagementError, 'An unexpected error occurred while deleting the license.'
    end
    false
  end

  def self.activate_license_for_user(assignment_id, user)
    _authorize_user_for_activation(user)
    assignment = _find_assignment_or_fail(assignment_id)
    assignment_owner = UserDAO.find_by_id(assignment.user_id)

    license = _find_license_or_fail(assignment.license_id)
    _ensure_license_is_active_for_activation(license)

    DB.transaction do
      _ensure_license_has_available_seats(license)
      _ensure_user_does_not_have_license_active(license, assignment_owner)

      LicenseAssignmentDAO.activate(assignment_id)

      if user.admin?
        AssignmentLogDAO.log_admin_activated_license(
          acting_user: user,
          target_assignment: assignment
        )
      else
        AssignmentLogDAO.log_user_activated_license(
          acting_user: user,
          target_assignment: assignment
        )
      end

      assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Validation failed during license assignment: #{e.errors.full_messages.join(', ')}"
  rescue NotAuthorizedError, NotFoundError, NotAvailableError, AlreadyAssignedError
    raise
  rescue StandardError => e
    puts "ERROR: Unexpected error in activate_license_for_user: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ServiceError, 'An unexpected error occurred while assigning the license.'
  end

  def self.deactivate_license_for_user(assignment_id, user)
    assignment = _find_assignment_or_fail(assignment_id)
    _authorize_user_for_assignment_action(assignment, user)
    _ensure_assignment_is_active(assignment)

    DB.transaction do
      LicenseAssignmentDAO.deactivate(assignment.assignment_id)
      deactivated_assignment = assignment.refresh

      if user.admin?
        AssignmentLogDAO.log_admin_deactivated_license(
          acting_user: user,
          target_assignment: deactivated_assignment
        )
      else
        AssignmentLogDAO.log_user_deactivated_license(
          acting_user: user,
          target_assignment: deactivated_assignment
        )
      end

      deactivated_assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Validation failed during license return: #{e.errors.full_messages.join(', ')}"
  rescue NotAuthorizedError, NotFoundError, ServiceError
    raise
  rescue StandardError => e
    puts "ERROR: Unexpected error in deactivate_license_for_user: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ServiceError, 'An unexpected error occurred while returning the license.'
  end

  def self.approve_assignment_for_user(license_id, target_user_id, admin_user)
    _authorize_admin(admin_user)
    license = _find_license_or_fail(license_id)
    target_user = _find_user_or_fail(target_user_id)

    existing_assignment = LicenseAssignmentDAO.find_one_by(
      license_id: license.license_id,
      user_id: target_user.user_id
    )
    if existing_assignment
      raise AlreadyAssignedError,
            "User already has an assignment for license '#{_license_display_name(license)}'."
    end

    DB.transaction do
      assignment_attributes = {
        license_id: license.license_id,
        user_id: target_user.user_id,
        is_active: false,
        assignment_date: Time.now
      }
      assignment = LicenseAssignmentDAO.create(assignment_attributes)

      AssignmentLogDAO.log_admin_approved_assignment(
        acting_user: admin_user,
        target_assignment: assignment
      )
      assignment
    end
  rescue DAO::RecordNotFound => e
    raise NotFoundError, e.message
  rescue AlreadyAssignedError, NotFoundError
    raise
  rescue StandardError => e
    puts "ERROR: Unexpected error in approve_assignment_for_user: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ServiceError, 'An unexpected error occurred while approving the assignment.'
  end

  def self.cancel_assignment_as_admin(assignment_id, admin_user)
    _authorize_admin(admin_user)
    assignment = _find_assignment_or_fail(assignment_id)

    raise ServiceError, 'Cannot cancel an active assignment. Deactivate it first.' if assignment.is_active?

    DB.transaction do
      AssignmentLogDAO.log_admin_canceled_assignment(
        acting_user: admin_user,
        target_assignment: assignment
      )
      LicenseAssignmentDAO.delete(assignment.assignment_id)
    end
    true
  rescue DAO::RecordNotFound
    raise NotFoundError, "License Assignment (ID: #{assignment_id}) not found."
  rescue ServiceError
    raise
  rescue StandardError => e
    puts "ERROR: Unexpected error in cancel_assignment_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise ServiceError, 'An unexpected error occurred while canceling the assignment.'
  end

  def self._authorize_user_for_activation(user)
    return if user.role?('User') || user.admin?

    raise NotAuthorizedError,
          'User role not permitted for activation.'
  end

  def self._find_license_or_fail(license_id)
    LicenseDAO.find!(license_id)
  rescue DAO::RecordNotFound
    raise NotFoundError, "License (ID: #{license_id}) not found."
  end

  def self._find_assignment_or_fail(assignment_id)
    LicenseAssignmentDAO.find!(assignment_id)
  rescue DAO::RecordNotFound
    raise NotFoundError, "License Assignment (ID: #{assignment_id}) not found."
  end

  def self._ensure_license_is_active_for_activation(license)
    return if license.status == 'Active'

    raise NotAvailableError,
          "License '#{_license_display_name(license)}' is not active and cannot be activated."
  end

  def self._ensure_license_has_available_seats(license)
    return unless license.available_seats <= 0

    raise NotAvailableError,
          "No available seats for license '#{_license_display_name(license)}'."
  end

  def self._ensure_user_does_not_have_license_active(license, user)
    existing_assignment = LicenseAssignmentDAO.find_one_by(
      license_id: license.license_id,
      user_id: user.user_id,
      is_active: true
    )
    return unless existing_assignment

    raise AlreadyAssignedError, "You already have license '#{_license_display_name(license)}' assigned and active."
  end

  def self._create_new_assignment(license, user)
    assignment_attributes = {
      license_id: license.license_id,
      user_id: user.user_id,
      is_active: true,
      assigned_at: Time.now
    }
    LicenseAssignmentDAO.create(assignment_attributes)
  end

  def self._authorize_user_for_assignment_action(assignment, user)
    return if user.admin? || assignment.user_id == user.user_id

    raise NotAuthorizedError, 'This license assignment does not belong to you, and you are not an administrator.'
  end

  def self._ensure_assignment_is_active(assignment)
    return if assignment.is_active

    raise ServiceError,
          "License assignment (ID: #{assignment.assignment_id}) is already inactive."
  end

  def self._license_display_name(license)
    name = license.license_name
    name = license.product&.product_name if name.nil? || name.empty?
    name || 'Unnamed License'
  end

  def self._authorize_admin(user)
    return if user.admin?

    raise NotAuthorizedError, 'Admin privileges required.'
  end

  def self._find_user_or_fail(user_id)
    UserDAO.find!(user_id)
  rescue DAO::RecordNotFound
    raise NotFoundError, "User (ID: #{user_id}) not found."
  end
end
