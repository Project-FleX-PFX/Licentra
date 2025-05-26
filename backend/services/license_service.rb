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

  private_class_method

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
