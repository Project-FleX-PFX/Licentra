# frozen_string_literal: true

require_relative '../models/license_assignment'
require_relative '../models/assignment_log'

require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'license_assignment_logging'
require_relative 'license_assignment_error_handling'

# Data Access Object for LicenseAssignment entities, handling database operations
class LicenseAssignmentDAO < BaseDAO
  def self.model_class
    LicenseAssignment
  end

  def self.primary_key
    :assignment_id
  end

  include CrudOperations

  class << self
    include LicenseAssignmentLogging
    include LicenseAssignmentErrorHandling
  end

  class << self
    def create(attributes)
      attributes[:assignment_date] ||= Time.now
      attributes[:is_active] = true if attributes[:is_active].nil?

      super
    end

    # --- SPECIAL QUERIES / ACTIONS ---

    def find_by_license(license_id)
      context = "finding assignments for license ID #{license_id}"
      with_error_handling(context) do
        assignments = where(license_id: license_id)
        log_assignments_for_license_fetched(license_id, assignments.size)
        assignments
      end
    end

    def find_by_user(user_id)
      context = "finding assignments for user ID #{user_id}"
      with_error_handling(context) do
        assignments = where(user_id: user_id)
        log_assignments_for_user_fetched(user_id, assignments.size)
        assignments
      end
    end

    def find_by_device(device_id)
      context = "finding assignments for device ID #{device_id}"
      with_error_handling(context) do
        assignments = where(device_id: device_id)
        log_assignments_for_device_fetched(device_id, assignments.size)
        assignments
      end
    end

    def find_active_assignments(options = {})
      active_criteria = { is_active: true }
      where(options.fetch(:where, {}).merge(active_criteria))
    end

    def find_inactive_assignments(options = {})
      inactive_criteria = { is_active: false }
      where(options.fetch(:where, {}).merge(inactive_criteria))
    end

    def activate(id)
      context = "activating license assignment ID #{id}"
      with_error_handling(context) do
        assignment = update(id, is_active: true)
        log_assignment_activated(assignment)
        assignment
      end
    end

    def deactivate(id)
      context = "deactivating license assignment ID #{id}"
      with_error_handling(context) do
        assignment = update(id, is_active: false)
        log_assignment_deactivated(assignment)
        assignment
      end
    end

    def find_active_for_user_with_details(user_id)
      model_class.where(user_id: user_id, is_active: true)
                 .eager(license: :product)
                 .all
    end
  end
end
