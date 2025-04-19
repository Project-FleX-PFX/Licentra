require_relative '../models/license_assignment'
require_relative '../models/assignment_log'

require_relative 'base_dao'
require_relative 'license_assignment_logging'
require_relative 'license_assignment_error_handling'

class LicenseAssignmentDAO < BaseDAO
  class << self
    include LicenseAssignmentLogging
    include LicenseAssignmentErrorHandling

    MODEL_PK = :assignment_id

    # CREATE
    def create(attributes)
      context = "creating license assignment"
      with_error_handling(context) do
        attributes[:assignment_date] ||= Time.now
        attributes[:is_active] = true if attributes[:is_active].nil?

        assignment = LicenseAssignment.new(attributes)

        if assignment.valid?
          assignment.save
          log_assignment_created(assignment)
          assignment
        else
          handle_validation_error(assignment, context)
        end
      end
    end

    # READ
    def find!(id)
      with_error_handling("finding license assignment with ID #{id}") do
        assignment = LicenseAssignment.eager(:license, :user, :device)[MODEL_PK => id]
        unless assignment
          handle_record_not_found(id)
        end
        log_assignment_found(assignment)
        assignment
      end
    end

    def find(id)
      with_error_handling("finding license assignment with ID #{id}") do
        assignment = LicenseAssignment.eager(:license, :user, :device)[MODEL_PK => id]
        log_assignment_found(assignment) if assignment
        assignment
      end
    end

    def find_one_by(criteria)
      with_error_handling("finding license assignment by criteria") do
        assignment = LicenseAssignment.eager(:license, :user, :device).first(criteria)
        log_assignment_found_by_criteria(criteria, assignment) if assignment
        assignment
      end
    end

    def find_one_by!(criteria)
      with_error_handling("finding license assignment by criteria") do
        assignment = find_one_by(criteria)
        unless assignment
          handle_record_not_found_by_criteria(criteria)
        end
        assignment
      end
    end

    def all(options = {})
      with_error_handling("fetching all license assignments") do
        dataset = LicenseAssignment.dataset
        dataset = dataset.where(options[:where]) if options[:where]
        dataset = dataset.order(options[:order]) if options[:order]
        dataset = dataset.eager(:license, :user, :device) if options[:eager_relations]
        assignments = dataset.all
        log_assignments_fetched(assignments.size)
        assignments
      end
    end

    def where(criteria)
      with_error_handling("filtering license assignments by criteria") do
        assignments = LicenseAssignment.eager(:license, :user, :device).where(criteria).all
        log_assignments_fetched_with_criteria(assignments.size, criteria)
        assignments
      end
    end

    # UPDATE
    def update(id, attributes)
      context = "updating license assignment with ID #{id}"
      with_error_handling(context) do
        assignment = find!(id)

        changed_columns_input = attributes.keys.select { |k| assignment.send(k) != attributes[k] }

        assignment.update(attributes)

        log_assignment_updated(assignment, changed_columns_input)
        assignment
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, context)
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting license assignment with ID #{id}") do
        assignment = find!(id)
        assignment.destroy
        log_assignment_deleted(assignment)
        true
      end
    end

    # --- SPECIAL QUERIES / ACTIONS ---
    def find_by_license(license_id)
       with_error_handling("finding assignments for license ID #{license_id}") do
         assignments = where(license_id: license_id)
         log_assignments_for_license_fetched(license_id, assignments.size)
         assignments
       end
     end

    def find_by_user(user_id)
       with_error_handling("finding assignments for user ID #{user_id}") do
         assignments = where(user_id: user_id)
         log_assignments_for_user_fetched(user_id, assignments.size)
         assignments
       end
     end

     def find_by_device(device_id)
        with_error_handling("finding assignments for device ID #{device_id}") do
          assignments = where(device_id: device_id)
          log_assignments_for_device_fetched(device_id, assignments.size)
          assignments
        end
     end

     def find_active_assignments(options = {})
       active_criteria = { is_active: true }
       merged_criteria = options.fetch(:where, {}).merge(active_criteria)
       where(merged_criteria)
     end

     def find_inactive_assignments(options = {})
        inactive_criteria = { is_active: false }
        merged_criteria = options.fetch(:where, {}).merge(inactive_criteria)
        where(merged_criteria)
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

  end
end
