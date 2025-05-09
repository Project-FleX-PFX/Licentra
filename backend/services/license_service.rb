# frozen_string_literal: true

# Service class which handles license assignments
class LicenseService
  class ServiceError < StandardError; end
  class NotAvailableError < ServiceError; end
  class AlreadyAssignedError < ServiceError; end
  class NotAuthorizedError < ServiceError; end

  def self.assign_license_to_user(license_id, user)
    raise NotAuthorizedError, 'User role not permitted for assignment.' unless user.role?('User')

    license = LicenseDAO.find(license_id)
    raise ArgumentError, 'License not found.' unless license
    raise NotAvailableError, 'License is not active.' unless license.status == 'Active'

    DB.transaction do
      current_assignments_count = LicenseAssignmentDAO.where(license_id: license.license_id, is_active: true).count
      available_seats = license.seat_count - current_assignments_count

      raise NotAvailableError, 'No available seats for this license.' if available_seats <= 0

      existing_assignment = LicenseAssignmentDAO.find_one_by(license_id: license.license_id, user_id: user.user_id,
                                                             is_active: true)
      raise AlreadyAssignedError, 'You already have this license assigned.' if existing_assignment

      assignment_attributes = {
        license_id: license.license_id,
        user_id: user.user_id,
        assignment_date: Time.now,
        is_active: true
      }
      new_assignment = LicenseAssignmentDAO.create(assignment_attributes)

      AssignmentLogDAO.create(
        assignment_id: new_assignment.assignment_id,
        action: 'ASSIGNED_SELF',
        details: "User '#{user.username}' (ID: #{user.user_id}) assigned license '#{license.license_name || license.product&.name}' (ID: #{license.license_id})."
      )
      new_assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Failed to assign license: #{e.message}"
  end

  def self.return_license_from_user(assignment_id, user)
    assignment = LicenseAssignmentDAO.find(assignment_id)
    raise ArgumentError, 'Assignment not found.' unless assignment

    unless assignment.user_id == user.user_id
      raise NotAuthorizedError,
            'This license assignment does not belong to you.'
    end
    raise ServiceError, 'License is already inactive.' unless assignment.is_active

    DB.transaction do
      updated_assignment = LicenseAssignmentDAO.deactivate(assignment.assignment_id)

      AssignmentLogDAO.create(
        assignment_id: updated_assignment.assignment_id,
        action: 'RETURNED_SELF',
        details: "User '#{user.username}' (ID: #{user.user_id}) returned license '#{assignment.license&.license_name || assignment.license&.product&.name}' (License ID: #{assignment.license_id})."
      )
      updated_assignment
    end
  rescue Sequel::ValidationFailed => e
    raise ServiceError, "Failed to return license: #{e.message}"
  end
end
