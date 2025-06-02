# frozen_string_literal: true

require_relative '../models/license_assignment'
require_relative '../models/license'
require_relative '../models/product'
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
      attributes[:is_active] = false if attributes[:is_active].nil?

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

    def find_detailed_by_user(user_id, options = {})
      context = "finding detailed assignments for user ID #{user_id}"
      with_error_handling(context) do
        dataset = model_class.where(user_id: user_id)

        dataset = dataset.eager(license: :product)

        order_criteria = options.fetch(:order, [Sequel.desc(:is_active), Sequel.desc(:assignment_date)])
        order_criteria = Array(order_criteria)
        dataset = dataset.order(*order_criteria) unless order_criteria.empty?

        assignments = dataset.all

        log_detailed_assignments_for_user_fetched(user_id, assignments.size)
        assignments
      end
    rescue StandardError => e
      log_error("Error in find_detailed_by_user for user_id #{user_id}: #{e.message}")
      raise
    end

    def find_detailed_by_license(license_id, options = {})
      context = "finding detailed assignments for license ID #{license_id}"
      with_error_handling(context) do
        dataset = model_class.where(license_id: license_id)
                             .where(Sequel.lit('user_id IS NOT NULL'))

        dataset = dataset.eager(user: :roles)

        order_criteria = options.fetch(:order, [Sequel.desc(:is_active), Sequel.asc(Sequel[:users][:username])])

        dataset = dataset.order(*Array(order_criteria))

        assignments = dataset.all

        log_detailed_assignments_for_license_fetched(license_id, assignments.size)
        assignments
      end
    rescue StandardError => e
      log_error("Error in find_detailed_by_license for license_id #{license_id}: #{e.message}")
      raise
    end

    def count_by_license(license_id)
      context = "finding assignments for license ID #{license_id}"
      with_error_handling(context) do
        count = where(license_id: license_id).count
        log_assignments_for_license_fetched(license_id, count)
        count
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

    def count_by_user(user_id)
      context = "counting assignments for user ID #{user_id}"
      with_error_handling(context) do
        count = where(user_id: user_id).count
        log_assignments_for_user_fetched(user_id, count)
        count
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
        # Zuweisung finden
        assignment = find(id)
        return nil unless assignment

        # Lizenz abrufen
        license = assignment.license

        # Prüfen, ob die Lizenz genügend freie Plätze hat
        if license.available_seats <= 0
          raise StandardError, 'Cannot activate assignment: License has no available seats'
        end

        # Zuweisung aktivieren
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
      find_detailed_by_user(user_id).select(&:is_active?)
    end

    def find_inactive_for_user_with_details(user_id)
      find_detailed_by_user(user_id).reject(&:is_active?)
    end
  end
end
