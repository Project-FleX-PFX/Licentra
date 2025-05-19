# frozen_string_literal: true

require_relative '../models/assignment_log'
require_relative 'base_dao'
require_relative 'assignment_log_logging'
require_relative 'assignment_log_error_handling'

# Data Access Object for immutable AssignmentLog records.
# Provides an interface for creating and querying assignment logs.
class AssignmentLogDAO < BaseDAO
  module Actions
    USER_ACTIVATED = 'user activated license'
    ADMIN_ACTIVATED = 'admin activated license'
    USER_DEACTIVATED = 'user deactivated license'
    ADMIN_DEACTIVATED = 'admin deactivated license'
    ADMIN_APPROVED = 'admin approved assignment'
    ADMIN_CANCELED = 'admin canceled assignment'
  end

  class << self
    include AssignmentLogLogging
    include AssignmentLogErrorHandling

    MODEL_PK = :log_id

    # --- CRUD Methoden ---

    # --- Specific Log Creation Methods ---

    def log_user_activated_license(acting_user:, target_assignment:)
      _create_generic_event_log(
        action_type: Actions::USER_ACTIVATED,
        acting_user: acting_user,
        target_assignment: target_assignment
      )
    end

    def log_admin_activated_license(acting_user:, target_assignment:)
      _create_generic_event_log(
        action_type: Actions::ADMIN_ACTIVATED,
        acting_user: acting_user,
        target_assignment: target_assignment
      )
    end

    def log_user_deactivated_license(acting_user:, target_assignment:)
      _create_generic_event_log(
        action_type: Actions::USER_DEACTIVATED,
        acting_user: acting_user,
        target_assignment: target_assignment
      )
    end

    def log_admin_deactivated_license(acting_user:, target_assignment:)
      _create_generic_event_log(
        action_type: Actions::ADMIN_DEACTIVATED,
        acting_user: acting_user,
        target_assignment: target_assignment
      )
    end

    def log_admin_approved_assignment(acting_user:, target_assignment:)
      _create_generic_event_log(
        action_type: Actions::ADMIN_APPROVED,
        acting_user: acting_user,
        target_assignment: target_assignment
      )
    end

    def log_admin_canceled_assignment(acting_user:, target_assignment:)
      _create_generic_event_log(
        action_type: Actions::ADMIN_CANCELED,
        acting_user: acting_user,
        target_assignment: target_assignment
      )
    end

    # READ
    def find!(id)
      context = "finding assignment log with ID #{id}"
      with_error_handling(context) do
        log_entry = AssignmentLog[id]
        handle_record_not_found(id, 'AssignmentLog') unless log_entry
        log_log_found(log_entry)
        log_entry
      end
    end

    def find(id)
      context = "finding assignment log with ID #{id}"
      with_error_handling(context) do
        log_entry = AssignmentLog[id]
        log_log_found(log_entry) if log_entry
        log_entry
      end
    end

    def find_one_by(criteria)
      context = "finding one assignment log by criteria: #{criteria}"
      with_error_handling(context) do
        log_entry = AssignmentLog.first(criteria)
        log_log_found_by_criteria(criteria, log_entry) if log_entry
        log_entry
      end
    end

    def find_one_by!(criteria)
      context = "finding one assignment log by criteria: #{criteria} (expecting one)"
      with_error_handling(context) do
        log_entry = find_one_by(criteria)
        handle_record_not_found_by_criteria(criteria, 'AssignmentLog') unless log_entry
        log_entry
      end
    end

    def all(options = {})
      context = 'fetching all assignment logs'
      with_error_handling(context) do
        dataset = AssignmentLog.dataset
        dataset = dataset.where(options[:where]) if options[:where]

        order_criteria = options.fetch(:order, [Sequel.desc(:log_timestamp), Sequel.desc(:log_id)])
        order_criteria = Array(order_criteria)
        dataset = dataset.order(*order_criteria) unless order_criteria.empty?

        logs = dataset.all
        log_logs_fetched(logs.size)
        logs
      end
    end

    def where(criteria)
      context = "filtering assignment logs by criteria: #{criteria}"
      with_error_handling(context) do
        logs = AssignmentLog.where(criteria).order(Sequel.desc(:log_timestamp), Sequel.desc(:log_id)).all
        log_logs_fetched_with_criteria(logs.size, criteria)
        logs
      end
    end

    # DELETE
    def delete(id)
      context = "deleting assignment log with ID #{id}"
      with_error_handling(context) do
        log_entry = find!(id)
        log_entry.destroy
        log_log_deleted(log_entry)
        true
      end
    end

    # --- SPECIAL QUERIES ---

    def delete_by_user(user_id)
      context = "deleting logs for user ID #{user_id}"
      with_error_handling(context) do
        count = AssignmentLog.where(user_id: user_id).delete
        count
      end
    end

    DEFAULT_PER_PAGE = 25

    def find_with_details(filters = {}, options = {})
      context = "finding assignment logs with details and filters: #{filters}"
      with_error_handling(context) do
        dataset = AssignmentLog.dataset
                               .order(Sequel.desc(:log_timestamp), Sequel.desc(:log_id))

        dataset = _apply_user_filter(dataset, filters[:user_id])
        dataset = _apply_license_filter(dataset, filters[:license_id])
        dataset = _apply_action_filter(dataset, filters[:action])
        dataset = _apply_object_filter(dataset, filters[:object])
        dataset = _apply_date_from_filter(dataset, filters[:date_from])
        dataset = _apply_date_to_filter(dataset, filters[:date_to])

        page = options.fetch(:page, 1).to_i
        per_page = options.fetch(:per_page, DEFAULT_PER_PAGE).to_i
        paginated_dataset = dataset.paginate(page, per_page)

        logs = paginated_dataset.all
        # rubocop:disable Layout/LineLength
        log_info("Fetched #{logs.size} assignment logs. Page: #{page}, PerPage: #{per_page}, TotalRecords: #{paginated_dataset.pagination_record_count}")
        # rubocop:enable Layout/LineLength

        {
          logs: logs,
          current_page: paginated_dataset.current_page,
          total_pages: paginated_dataset.page_count,
          total_entries: paginated_dataset.pagination_record_count
        }
      end
    end

    private

    # Helper to generate log entries for common assignment-related actions.
    # acting_user: The user performing the action.
    # target_assignment: The LicenseAssignment object being acted upon.
    #                  Its associated user and license will be denormalized into the log.
    def _create_generic_event_log(action_type:, acting_user:, target_assignment:,
                                  custom_object_name: 'LicenseAssignment', additional_details_info: nil)
      context = "creating specific log for action '#{action_type}'"
      with_error_handling(context) do
        current_target_user = target_assignment&.user
        current_target_license = target_assignment&.license

        unless current_target_user && current_target_license
          # rubocop:disable Layout/LineLength
          error_msg = "Cannot create log: target_assignment (ID: #{target_assignment&.assignment_id}) must have an associated user and license."
          # rubocop:enable Layout/LineLength
          log_error("#{context} - #{error_msg}")
          raise ArgumentError, error_msg
        end

        details_string = _format_standard_log_details(
          acting_user: acting_user,
          action_description: action_type,
          target_license: current_target_license,
          original_assignment_id: target_assignment.assignment_id,
          additional_info: additional_details_info
        )

        _persist_log_entry(
          action: action_type,
          object: custom_object_name,
          target_user: current_target_user,
          target_license: current_target_license,
          details: details_string
        )
      end
    end

    # Formats the human-readable details string for standard log entries.
    def _format_standard_log_details(acting_user:, action_description:, target_license:, original_assignment_id:,
                                     additional_info: nil)
      actor_info = if acting_user
                     "User '#{acting_user.username}' (ID: #{acting_user.user_id})"
                   else
                     'System'
                   end

      # rubocop:disable Layout/LineLength
      base_details = "#{actor_info} performed action '#{action_description}' for license '#{target_license.license_name}' (License ID: #{target_license.license_id}). Assignment ID: #{original_assignment_id}."
      # rubocop:enable Layout/LineLength

      additional_info ? "#{base_details} #{additional_info}" : base_details
    end

    # Core method to create and save the log entry to the database.
    # target_user and target_license are the entities whose data is denormalized.
    def _persist_log_entry(action:, object:, target_user:, target_license:, details: nil)
      context = "persisting assignment log for action '#{action}' on '#{object}'"
      with_error_handling(context) do
        unless target_user&.user_id && target_user.username && target_user.email
          raise ArgumentError,
                'Invalid or incomplete target_user object provided for logging. Required: user_id, username, email.'
        end
        unless target_license&.license_id && target_license.license_name
          raise ArgumentError,
                'Invalid or incomplete target_license object provided for logging. Required: license_id, name.'
        end

        attributes = {
          action: action,
          object: object,
          license_id: target_license.license_id,
          license_name: target_license.license_name,
          user_id: target_user.user_id,
          username: target_user.username,
          email: target_user.email,
          details: details,
          log_timestamp: Time.now
        }

        log_entry = AssignmentLog.new(attributes)
        if log_entry.valid?
          log_entry.save_changes
          log_log_created(log_entry)
          log_entry
        else
          handle_validation_error(log_entry, context, log_entry.errors.full_messages.join('; '))
        end
      end
    end

    def _apply_user_filter(dataset, user_id_param)
      user_id = user_id_param.to_i
      return dataset unless user_id.positive?

      dataset.where(user_id: user_id)
    end

    def _apply_license_filter(dataset, license_id_param)
      license_id = license_id_param.to_i
      return dataset unless license_id.positive?

      dataset.where(license_id: license_id)
    end

    def _apply_action_filter(dataset, action_param)
      action = action_param&.strip
      return dataset if action.nil? || action.empty?

      dataset.where(Sequel.ilike(:action, "%#{action}%"))
    end

    def _apply_object_filter(dataset, object_param)
      object = object_param&.strip
      return dataset if object.nil? || object.empty?

      dataset.where(Sequel.ilike(:object, "%#{object}%"))
    end

    def _apply_date_from_filter(dataset, date_from_param)
      parsed_date = _parse_date(date_from_param)
      return dataset unless parsed_date

      dataset.where { log_timestamp >= parsed_date.to_time.utc }
    end

    def _apply_date_to_filter(dataset, date_to_param)
      parsed_date = _parse_date(date_to_param)
      return dataset unless parsed_date

      end_of_day_timestamp = (parsed_date.to_time + (24 * 60 * 60) - 1).utc
      dataset.where { log_timestamp <= end_of_day_timestamp }
    end

    def handle_validation_error(model, context, messages = nil)
      error_details = messages || model&.errors&.full_messages&.join('; ') || 'Unknown validation error'
      log_error("#{context} - Validation failed: #{error_details}")
      nil
    end

    def handle_record_not_found(id, model_name = 'Record')
      log_error("#{model_name} with ID #{id} not found.")
      raise Sequel::NoMatchingRow, "#{model_name} with ID #{id} not found."
    end

    def handle_record_not_found_by_criteria(criteria, model_name = 'Record')
      log_error("#{model_name} not found for criteria: #{criteria}.")
      raise Sequel::NoMatchingRow, "#{model_name} not found for criteria: #{criteria}."
    end
  end
end
