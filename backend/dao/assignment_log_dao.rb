# frozen_string_literal: true

require_relative '../models/assignment_log'
require_relative 'base_dao'
require_relative 'assignment_log_logging'
require_relative 'assignment_log_error_handling'

# Data Access Object for AssignmentLog records.
# Provides an interface for all CRUD operations and custom queries related to assignment logs.
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

    # CREATE
    def create_log(action:, object:, assignment: nil, details: nil)
      context = "creating assignment log for action '#{action}' on '#{object}'"
      with_error_handling(context) do
        attributes = {
          action: action,
          object: object,
          assignment_id: assignment&.assignment_id,
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

    def create(attributes)
      context = 'creating assignment log with generic attributes'
      with_error_handling(context) do
        attributes[:log_timestamp] ||= Time.now

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

    # UPDATE
    def update(id, attributes)
      context = "updating assignment log with ID #{id}"
      with_error_handling(context) do
        attributes.delete(:assignment_id)
        attributes.delete(:log_timestamp)
        attributes.delete(:log_id)

        log_entry = find!(id)
        log_entry.set(attributes)

        if log_entry.valid?
          log_entry.save_changes
          log_log_updated(log_entry)
          log_entry
        else
          handle_validation_error(log_entry, context, log_entry.errors.full_messages.join('; '))
        end
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, context, e.errors.full_messages.join('; '))
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

    def find_by_assignment(assignment_id, options = {})
      context = "finding logs for assignment ID #{assignment_id}"
      with_error_handling(context) do
        logs = all(options.merge(where: { assignment_id: assignment_id }.merge(options[:where] || {})))
        log_logs_for_assignment_fetched(assignment_id, logs.size)
        logs
      end
    end

    def delete_by_assignment(assignment_id)
      context = "deleting logs for assignment ID #{assignment_id}"
      with_error_handling(context) do
        count = AssignmentLog.where(assignment_id: assignment_id).delete
        log_logs_deleted_for_assignment(assignment_id, count)
        count
      end
    end

    DEFAULT_PER_PAGE = 25

    def find_with_details(filters = {}, options = {})
      context = "finding assignment logs with details and filters: #{filters}"
      with_error_handling(context) do
        dataset = AssignmentLog.dataset
                               .eager(license_assignment: [{ user: [] }, { license: :product }])
                               .order(Sequel.desc(:log_timestamp), Sequel.desc(:log_id))

        dataset = _apply_user_filter(dataset, filters[:user_id])
        dataset = _apply_action_filter(dataset, filters[:action])
        dataset = _apply_object_filter(dataset, filters[:object])
        dataset = _apply_date_from_filter(dataset, filters[:date_from])
        dataset = _apply_date_to_filter(dataset, filters[:date_to])

        page = options.fetch(:page, 1).to_i
        per_page = options.fetch(:per_page, DEFAULT_PER_PAGE).to_i
        paginated_dataset = dataset.paginate(page, per_page)

        logs = paginated_dataset.all
        log_info("Fetched #{logs.size} assignment logs. Page: #{page}, PerPage: #{per_page}, TotalRecords: #{paginated_dataset.pagination_record_count}")

        {
          logs: logs,
          current_page: paginated_dataset.current_page,
          total_pages: paginated_dataset.page_count,
          total_entries: paginated_dataset.pagination_record_count
        }
      end
    end

    private

    def _apply_user_filter(dataset, user_id_param)
      user_id = user_id_param.to_i
      return dataset unless user_id.positive?

      relevant_assignment_ids = LicenseAssignment.where(user_id: user_id).select_map(:assignment_id)

      if relevant_assignment_ids.empty?
        dataset.where(1 => 0)
      else
        dataset.where(assignment_id: relevant_assignment_ids)
      end
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
