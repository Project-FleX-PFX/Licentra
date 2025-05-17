# frozen_string_literal: true

require_relative '../dao/license_dao'
require_relative '../dao/license_assignment_dao'
require_relative '../dao/assignment_log_dao'
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

  # === Public Interface ===

  def self.activate_license_for_user(license_id, user)
    _authorize_user_for_assignment(user)

    license = _find_license_or_fail(license_id)
    _ensure_license_is_active_for_assignment(license)

    DB.transaction do
      _ensure_license_has_available_seats(license)
      _ensure_user_does_not_have_license_active(license, user)

      new_assignment = _create_new_assignment(license, user)
      _log_assignment_action(
        assignment_instance: new_assignment,
        actor: user,
        license_instance: license,
        action_constant: user.admin? ? AssignmentLogDAO::Actions::ADMIN_ACTIVATED : AssignmentLogDAO::Actions::USER_ACTIVATED,
        custom_details: "#{user.admin? ? 'Admin' : 'User'} activated license."
      )

      new_assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Validation failed during license assignment: #{e.errors.full_messages.join(', ')}"
  rescue NotAuthorizedError, NotFoundError, NotAvailableError, AlreadyAssignedError
    raise
  rescue StandardError => e
    raise ServiceError, 'An unexpected error occurred while assigning the license.'
  end

  def self.deactivate_license_for_user(assignment_id, user)
    assignment = _find_assignment_or_fail(assignment_id)
    _authorize_user_for_assignment_action(assignment, user)
    _ensure_assignment_is_active(assignment)

    DB.transaction do
      updated_assignment = _deactivate_assignment(assignment)
      _log_assignment_action(
        assignment_instance: updated_assignment,
        actor: user,
        license_instance: assignment.license,
        action_constant: user.admin? ? AssignmentLogDAO::Actions::ADMIN_DEACTIVATED : AssignmentLogDAO::Actions::USER_DEACTIVATED,
        custom_details: "#{user.admin? ? 'Admin' : 'User'} deactivated license."
      )

      updated_assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Validation failed during license return: #{e.errors.full_messages.join(', ')}"
  rescue NotAuthorizedError, NotFoundError, ServiceError
    raise
  rescue StandardError => e
    raise ServiceError, 'An unexpected error occurred while returning the license.'
  end

  private_class_method

  def self._authorize_user_for_activation(user)
    return if user.role?('User') || user.admin?

    raise NotAuthorizedError,
          'User role not permitted for activation.'
  end

  def self._find_license_or_fail(license_id)
    LicenseDAO.find!(license_id)
  rescue Sequel::NoMatchingRow
    raise NotFoundError, "License (ID: #{license_id}) not found."
  end

  def self._find_assignment_or_fail(assignment_id)
    LicenseAssignmentDAO.find!(assignment_id)
  rescue Sequel::NoMatchingRow
    raise NotFoundError, "License Assignment (ID: #{assignment_id}) not found."
  end

  def self._ensure_license_is_active_for_assignment(license)
    return if license.status == 'Active'

    raise NotAvailableError,
          "License '#{_license_display_name(license)}' is not active and cannot be assigned."
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
    return if user.admin?
    return if assignment.user_id == user.user_id

    raise NotAuthorizedError, 'This license assignment does not belong to you, and you are not an administrator.'
  end

  def self._ensure_assignment_is_active(assignment)
    return if assignment.is_active

    raise ServiceError,
          "License assignment (ID: #{assignment.assignment_id}) is already inactive."
  end

  def self._deactivate_assignment(assignment)
    LicenseAssignmentDAO.deactivate(assignment.assignment_id)
  end

  def self._log_assignment_action(assignment_instance:, actor:, license_instance:, action_constant:,
                                  custom_details: nil)
    object_name = _license_display_name(license_instance)

    details_message = "User '#{actor.username}' (ID: #{actor.user_id}) triggered action. "
    details_message += "Assignment ID: #{assignment_instance.assignment_id}. "
    details_message += "License ID: #{license_instance.license_id}. "
    details_message += custom_details if custom_details

    AssignmentLogDAO.create_log(
      action: action_constant,
      object: object_name,
      assignment: assignment_instance,
      details: details_message.strip
    )
  rescue StandardError => e
    puts "WARNING: Failed to log assignment action: #{e.class} - #{e.message}"
  end

  def self._license_display_name(license)
    name = license.license_name
    name = license.product&.product_name if name.nil? || name.empty?
    name || 'Unnamed License'
  end
end
