# frozen_string_literal: true

require_relative '../models/security_log'
require_relative '../models/user'
require_relative 'base_dao'
require_relative 'security_log_logging'
require_relative 'security_log_error_handling'

# Data Access Object for SecurityLog records.
# Provides an interface for CRUD operations and custom queries for security-relevant logs.
class SecurityLogDAO < BaseDAO
  module Actions
    LOGIN_SUCCESS = 'login success'
    LOGIN_FAILURE = 'login failure'
    PASSWORD_RESET_REQUEST = 'password reset request'
    PASSWORD_CHANGED = 'password changed'
    USER_CREATED = 'user created'
    USER_UPDATED = 'user updated'
    USER_DELETED = 'user deleted'
    PRODUCT_CREATED = 'product created'
    PRODUCT_UPDATED = 'product updated'
    PRODUCT_DELETED = 'product deleted'
    LICENSE_CREATED = 'license created'
    LICENSE_UPDATED = 'license updated'
    LICENSE_DELETED = 'license deleted'
  end

  class << self
    include SecurityLogLogging
    include SecurityLogErrorHandling

    MODEL_PK = :log_id

    # --- CRUD Methoden ---

    # CREATE
    def create_log(action:, object:, user: nil, details: nil)
      context = "creating security log for action '#{action}' on object '#{object}'"
      with_error_handling(context) do
        attributes = {
          action: action,
          object: object,
          user_id: user&.id,
          details: details,
          log_timestamp: Time.now
        }

        log_entry = SecurityLog.new(attributes)
        if log_entry.valid?
          log_entry.save_changes
          log_security_log_created(log_entry)
          log_entry
        else
          handle_validation_error(log_entry, context, log_entry.errors.full_messages.join('; '))
        end
      end
    end

    def create(attributes)
      context = 'creating security log with generic attributes'
      with_error_handling(context) do
        attributes[:log_timestamp] ||= Time.now

        log_entry = SecurityLog.new(attributes)
        if log_entry.valid?
          log_entry.save_changes
          log_security_log_created(log_entry)
          log_entry
        else
          handle_validation_error(log_entry, context, log_entry.errors.full_messages.join('; '))
        end
      end
    end

    # READ
    def find!(id)
      context = "finding security log with ID #{id}"
      with_error_handling(context) do
        log_entry = SecurityLog[id]
        handle_record_not_found(id, 'SecurityLog') unless log_entry
        log_security_log_found(log_entry)
        log_entry
      end
    end

    def find(id)
      context = "finding security log with ID #{id}"
      with_error_handling(context) do
        log_entry = SecurityLog[id]
        log_security_log_found(log_entry) if log_entry
        log_entry
      end
    end

    def find_one_by(criteria)
      context = "finding one security log by criteria: #{criteria}"
      with_error_handling(context) do
        log_entry = SecurityLog.first(criteria)
        log_security_log_found_by_criteria(criteria, log_entry) if log_entry
        log_entry
      end
    end

    def find_one_by!(criteria)
      context = "finding one security log by criteria: #{criteria} (expecting one)"
      with_error_handling(context) do
        log_entry = find_one_by(criteria)
        handle_record_not_found_by_criteria(criteria, 'SecurityLog') unless log_entry
        log_entry
      end
    end

    def all(options = {})
      context = 'fetching all security logs'
      with_error_handling(context) do
        dataset = SecurityLog.dataset
        dataset = dataset.where(options[:where]) if options[:where]

        order_criteria = options.fetch(:order, [Sequel.desc(:log_timestamp), Sequel.desc(:log_id)])
        order_criteria = Array(order_criteria)
        dataset = dataset.order(*order_criteria) unless order_criteria.empty?

        logs = dataset.all
        log_security_logs_fetched(logs.size)
        logs
      end
    end

    def where(criteria, options = {})
      context = "filtering security logs by criteria: #{criteria}"
      with_error_handling(context) do
        dataset = SecurityLog.where(criteria)
        order_criteria = options.fetch(:order, [Sequel.desc(:log_timestamp), Sequel.desc(:log_id)])
        order_criteria = Array(order_criteria)
        dataset = dataset.order(*order_criteria) unless order_criteria.empty?

        logs = dataset.all
        log_security_logs_fetched_with_criteria(logs.size, criteria)
        logs
      end
    end

    # UPDATE
    def update(id, attributes)
      context = "updating security log with ID #{id}"
      with_error_handling(context) do
        attributes.delete(:user_id)
        attributes.delete(:log_timestamp)
        attributes.delete(:log_id)
        attributes.delete(:action)
        attributes.delete(:object)

        log_entry = find!(id)
        log_entry.set(attributes)

        if log_entry.valid?
          log_entry.save_changes
          log_security_log_updated(log_entry)
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
      context = "deleting security log with ID #{id}"
      with_error_handling(context) do
        log_entry = find!(id)
        log_entry.destroy
        log_security_log_deleted(log_entry)
        true
      end
    end

    # --- SPECIAL QUERIES ---

    def find_by_user(user_id, options = {})
      context = "finding security logs for user ID #{user_id}"
      with_error_handling(context) do
        query_options = { where: { user_id: user_id } }
        query_options[:order] = options[:order] if options[:order]

        logs = all(query_options)
        log_security_logs_for_user_fetched(user_id, logs.size)
        logs
      end
    end

    DEFAULT_PER_PAGE = 25

    def find_with_details(filters = {}, options = {})
      context = "finding security logs with details and filters: #{filters}"
      with_error_handling(context) do
        dataset = SecurityLog.dataset.eager(:user)

        default_order = [Sequel.desc(Sequel[:security_logs][:log_timestamp]),
                         Sequel.desc(Sequel[:security_logs][:log_id])]
        order_criteria = options.fetch(:order, default_order)
        order_criteria = Array(order_criteria)
        dataset = dataset.order(*order_criteria) unless order_criteria.empty?

        dataset = _apply_filter_user_id(dataset, filters[:user_id])
        dataset = _apply_filter_action(dataset, filters[:action])
        dataset = _apply_filter_object(dataset, filters[:object])
        dataset = _apply_filter_date_from(dataset, filters[:date_from])
        dataset = _apply_filter_date_to(dataset, filters[:date_to])
        dataset = _apply_filter_details_contains(dataset, filters[:details_contains])

        page = options.fetch(:page, 1).to_i
        per_page = options.fetch(:per_page, DEFAULT_PER_PAGE).to_i
        paginated_dataset = dataset.paginate(page, per_page)

        logs = paginated_dataset.all
        log_info("Fetched #{logs.size} security logs. Page: #{page}, PerPage: #{per_page}, TotalRecords: #{paginated_dataset.pagination_record_count}")

        {
          logs: logs,
          current_page: paginated_dataset.current_page,
          total_pages: paginated_dataset.page_count,
          total_entries: paginated_dataset.pagination_record_count
        }
      end
    end

    private

    def _apply_filter_user_id(dataset, user_id_param)
      return dataset if user_id_param.nil? || user_id_param.to_s.strip.empty?

      id_val = user_id_param.to_i

      return dataset unless id_val.positive?

      dataset.where(Sequel[:security_logs][:user_id] => id_val)
    end

    def _apply_filter_action(dataset, action_param)
      action = action_param&.strip
      return dataset if action.nil? || action.empty?

      dataset.where(Sequel.ilike(Sequel[:security_logs][:action], "%#{action}%"))
    end

    def _apply_filter_object(dataset, object_param)
      object = object_param&.strip
      return dataset if object.nil? || object.empty?

      dataset.where(Sequel.ilike(Sequel[:security_logs][:object], "%#{object}%"))
    end

    def _apply_filter_details_contains(dataset, details_query_param)
      query = details_query_param&.strip
      return dataset if query.nil? || query.empty?

      dataset.where(Sequel.ilike(Sequel[:security_logs][:details], "%#{query}%"))
    end

    def _apply_filter_date_from(dataset, date_from_param)
      parsed_date = _parse_date(date_from_param)
      return dataset unless parsed_date

      dataset.where { Sequel[:security_logs][:log_timestamp] >= parsed_date.to_time.utc }
    end

    def _apply_filter_date_to(dataset, date_to_param)
      parsed_date = _parse_date(date_to_param)
      return dataset unless parsed_date

      end_of_day_timestamp = (parsed_date.to_time + (24 * 60 * 60) - 1).utc
      dataset.where { Sequel[:security_logs][:log_timestamp] <= end_of_day_timestamp }
    end
  end
end
