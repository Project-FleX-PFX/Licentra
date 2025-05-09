# frozen_string_literal: true

# Service class which handles license assignments
class LicenseService
  # Custom Error Classes
  class ServiceError < StandardError; end
  class NotAvailableError < ServiceError; end
  class AlreadyAssignedError < ServiceError; end
  class NotAuthorizedError < ServiceError; end
  class NotFoundError < ServiceError; end

  # === Public Interface ===

  def self.assign_license_to_user(license_id, user)
    _authorize_user_for_assignment(user)

    license = _find_license_or_fail(license_id)
    _ensure_license_is_active_for_assignment(license)

    DB.transaction do
      _ensure_license_has_available_seats(license)
      _ensure_user_does_not_have_license_active(license, user)

      new_assignment = _create_new_assignment(license, user)
      _log_assignment_action(new_assignment, user, license, 'ASSIGNED_SELF')

      new_assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Validation failed during license assignment: #{e.message}"
  rescue NotAuthorizedError, NotFoundError, NotAvailableError, AlreadyAssignedError
    raise
  rescue StandardError => e
    raise ServiceError, 'An unexpected error occurred while assigning the license.'
  end

  def self.return_license_from_user(assignment_id, user)
    assignment = _find_assignment_or_fail(assignment_id)
    _authorize_user_for_assignment_action(assignment, user)
    _ensure_assignment_is_active(assignment)

    DB.transaction do
      updated_assignment = _deactivate_assignment(assignment)
      _log_assignment_action(updated_assignment, user, assignment.license, 'RETURNED_SELF')

      updated_assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Validation failed during license return: #{e.message}"
  rescue NotAuthorizedError, NotFoundError, ServiceError
    raise
  rescue StandardError => e
    raise ServiceError, 'An unexpected error occurred while returning the license.'
  end

  # === Private Helper Methods ===
  private_class_method

  def self._authorize_user_for_assignment(user)
    raise NotAuthorizedError, 'User role not permitted for assignment.' unless user.role?('User')
  end

  def self._find_license_or_fail(license_id)
    LicenseDAO.find(license_id) || (raise NotFoundError, "License (ID: #{license_id}) not found.")
  end

  def self._find_assignment_or_fail(assignment_id)
    LicenseAssignmentDAO.find(assignment_id) || (raise NotFoundError,
                                                       "License Assignment (ID: #{assignment_id}) not found.")
  end

  def self._ensure_license_is_active_for_assignment(license)
    return if license.status == 'Active'

    raise NotAvailableError,
          "License '#{_license_display_name(license)}' is not active."
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
      user_id: user.user_id
    }
    LicenseAssignmentDAO.create(assignment_attributes)
  end

  def self._authorize_user_for_assignment_action(assignment, user)
    return if assignment.user_id == user.user_id

    raise NotAuthorizedError, 'This license assignment does not belong to you.'
  end

  def self._ensure_assignment_is_active(assignment)
    return if assignment.is_active

    raise ServiceError,
          "License assignment (ID: #{assignment.assignment_id}) is already inactive."
  end

  def self._deactivate_assignment(assignment)
    LicenseAssignmentDAO.deactivate(assignment.assignment_id)
  end

  def self._log_assignment_action(assignment_instance, user, license_instance, action_type)
    details = "User '#{user.username}' (ID: #{user.user_id}) performed action '#{action_type}' " \
              "for license '#{_license_display_name(license_instance)}' (License ID: #{license_instance.license_id}). " \
              "Assignment ID: #{assignment_instance.assignment_id}."

    AssignmentLogDAO.create(
      assignment_id: assignment_instance.assignment_id,
      action: action_type,
      details: details
    )
  end

  def self._license_display_name(license)
    name = license.license_name
    name = license.product.product_name if name.nil? || name.empty?
    name || 'Unnamed License'
  end
end
