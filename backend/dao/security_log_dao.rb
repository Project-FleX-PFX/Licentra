# frozen_string_literal: true

require_relative '../models/security_log'
require_relative '../models/user'
require_relative 'base_dao'
require_relative 'user_dao'
require_relative 'security_log_logging'
require_relative 'security_log_error_handling'

# Data Access Object for immutable SecurityLog records.
# Provides an interface for creating and querying security-relevant logs.
class SecurityLogDAO < BaseDAO
  module Actions
    LOGIN_SUCCESS          = 'login success'
    LOGIN_FAILURE          = 'login failure'
    PASSWORD_RESET_REQUEST = 'password reset request'
    PASSWORD_CHANGED       = 'password changed'
    USER_CREATED           = 'user created'
    USER_UPDATED           = 'user updated'
    USER_DELETED           = 'user deleted'
    USER_LOCKED            = 'user locked'
    PRODUCT_CREATED        = 'product created'
    PRODUCT_UPDATED        = 'product updated'
    PRODUCT_DELETED        = 'product deleted'
    LICENSE_CREATED        = 'license created'
    LICENSE_UPDATED        = 'license updated'
    LICENSE_DELETED        = 'license deleted'

    ALL_ACTIONS = [
      LOGIN_SUCCESS, LOGIN_FAILURE, PASSWORD_RESET_REQUEST, PASSWORD_CHANGED,
      USER_CREATED, USER_UPDATED, USER_DELETED, USER_LOCKED,
      PRODUCT_CREATED, PRODUCT_UPDATED, PRODUCT_DELETED,
      LICENSE_CREATED, LICENSE_UPDATED, LICENSE_DELETED
    ].freeze
  end

  module Objects
    USER_SESSION = 'UserSession'
    USER_ACCOUNT = 'UserAccount'
    PRODUCT = 'Product'
    LICENSE = 'License'
    ALL_OBJECTS = [USER_SESSION, USER_ACCOUNT, PRODUCT, LICENSE].freeze
  end

  class << self
    include SecurityLogLogging
    include SecurityLogErrorHandling

    MODEL_PK = :log_id

    # Represents a placeholder for actions where the user is not yet authenticated
    # or for system-level events not directly tied to a specific logged-in user.
    def _system_user_for_logging
      @_system_user_for_logging ||= find_or_create_special_user('System', 'system@internal.log')
    end

    def _unknown_user_for_logging
      @_unknown_user_for_logging ||= find_or_create_special_user('Unknown', 'unknown@internal.log')
    end

    # --- Specific Log Creation Methods ---

    def log_login_success(user:)
      details = "User '#{user.username}' (ID: #{user.user_id}) successfully logged in."
      create_log_entry(action: Actions::LOGIN_SUCCESS, object: Objects::ALL_OBJECTS[0], acting_user: user,
                       details: details)
    end

    def log_login_failure(attempted_username:, ip_address: nil)
      details = "Failed login attempt for username '#{attempted_username}'."
      details += " IP: #{ip_address}." if ip_address
      create_log_entry(action: Actions::LOGIN_FAILURE, object: Objects::ALL_OBJECTS[0], acting_user: _unknown_user_for_logging,
                       details: details)
    end

    def log_password_reset_request(user_making_request:, target_email:)
      details = "Password reset requested for email '#{target_email}' by user '#{user_making_request.username}' (ID: #{user_making_request.user_id})."
      create_log_entry(action: Actions::PASSWORD_RESET_REQUEST, object: Objects::ALL_OBJECTS[1],
                       acting_user: user_making_request, details: details)
    end

    def log_password_changed(user_who_changed_password:)
      details = "Password changed for user '#{user_who_changed_password.username}' (ID: #{user_who_changed_password.user_id})."
      create_log_entry(action: Actions::PASSWORD_CHANGED, object: Objects::ALL_OBJECTS[1],
                       acting_user: user_who_changed_password, details: details)
    end

    def log_user_created(acting_user:, created_user:)
      details = "User '#{created_user.username}' (ID: #{created_user.user_id}) was created by '#{acting_user.username}' (ID: #{acting_user.user_id})."
      create_log_entry(action: Actions::USER_CREATED, object: Objects::ALL_OBJECTS[1], acting_user: acting_user,
                       details: details)
    end

    def log_user_updated(acting_user:, updated_user:, changes_description: 'details updated')
      details = "User '#{updated_user.username}' (ID: #{updated_user.user_id}) was updated by '#{acting_user.username}' (ID: #{acting_user.user_id}). Changes: #{changes_description}."
      create_log_entry(action: Actions::USER_UPDATED, object: Objects::ALL_OBJECTS[1], acting_user: acting_user,
                       details: details)
    end

    def log_user_deleted(acting_user:, deleted_user_username:, deleted_user_id:)
      details = "User '#{deleted_user_username}' (ID: #{deleted_user_id}) was deleted by '#{acting_user.username}' (ID: #{acting_user.user_id})."
      create_log_entry(action: Actions::USER_DELETED, object: Objects::ALL_OBJECTS[1], acting_user: acting_user,
                       details: details)
    end

    def log_user_locked(locked_user:, acting_user:,
                        reason: 'Account locked due to too many invalid login attempts.')
      details = "User '#{locked_user.username}' (ID: #{locked_user.user_id}) was locked by '#{acting_user.username}' (ID: #{acting_user.user_id}). Reason: #{reason}."
      create_log_entry(action: Actions::USER_LOCKED, object: Objects::ALL_OBJECTS[1], acting_user: acting_user,
                       details: details)
    end

    def log_product_created(acting_user:, product:)
      details = "Product '#{product.product_name}' (ID: #{product.product_id}) was created by '#{acting_user.username}' (ID: #{acting_user.user_id})."
      create_log_entry(action: Actions::PRODUCT_CREATED, object: Objects::ALL_OBJECTS[2], acting_user: acting_user,
                       details: details)
    end

    def log_product_updated(acting_user:, product:, changes_description: 'details updated')
      details = "Product '#{product.product_name}' (ID: #{product.product_id}) was updated by '#{acting_user.username}' (ID: #{acting_user.user_id}). Changes: #{changes_description}."
      create_log_entry(action: Actions::PRODUCT_UPDATED, object: Objects::ALL_OBJECTS[2], acting_user: acting_user,
                       details: details)
    end

    def log_product_deleted(acting_user:, deleted_product_name:, deleted_product_id:)
      details = "Product '#{deleted_product_name}' (ID: #{deleted_product_id}) was deleted by '#{acting_user.username}' (ID: #{acting_user.user_id})."
      create_log_entry(action: Actions::PRODUCT_DELETED, object: Objects::ALL_OBJECTS[2], acting_user: acting_user,
                       details: details)
    end

    def log_license_created(acting_user:, license:)
      details = "License '#{license.license_name}' (ID: #{license.license_id}) for product '#{license.product&.product_name}' was created by '#{acting_user.username}' (ID: #{acting_user.user_id})."
      create_log_entry(action: Actions::LICENSE_CREATED, object: Objects::ALL_OBJECTS[3], acting_user: acting_user,
                       details: details)
    end

    def log_license_updated(acting_user:, license:, changes_description: 'details updated')
      details = "License '#{license.license_name}' (ID: #{license.license_id}) was updated by '#{acting_user.username}' (ID: #{acting_user.user_id}). Changes: #{changes_description}."
      create_log_entry(action: Actions::LICENSE_UPDATED, object: Objects::ALL_OBJECTS[3], acting_user: acting_user,
                       details: details)
    end

    def log_license_deleted(acting_user:, deleted_license_name:, deleted_license_id:)
      details = "License '#{deleted_license_name}' (ID: #{deleted_license_id}) was deleted by '#{acting_user.username}' (ID: #{acting_user.user_id})."
      create_log_entry(action: Actions::LICENSE_DELETED, object: Objects::ALL_OBJECTS[3], acting_user: acting_user,
                       details: details)
    end

    # --- CRUD Methoden ---

    # READ
    def distinct_actions
      context = 'fetching distinct security log actions'
      with_error_handling(context) do
        Actions::ALL_ACTIONS.sort
      end
    end

    def distinct_objects
      context = 'fetching distinct security log objects'
      with_error_handling(context) do
        Objects::ALL_OBJECTS.sort
      end
    end

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
        dataset = SecurityLog.dataset

        default_order = [Sequel.desc(:log_timestamp), Sequel.desc(:log_id)]
        order_criteria = options.fetch(:order, default_order)
        order_criteria = Array(order_criteria)
        dataset = dataset.order(*order_criteria) unless order_criteria.empty?

        dataset = _apply_filter_user_id(dataset, filters[:user_id])
        dataset = _apply_filter_username(dataset, filters[:username])
        dataset = _apply_filter_email(dataset, filters[:email])
        dataset = _apply_filter_action(dataset, filters[:action])
        dataset = _apply_filter_object(dataset, filters[:object])
        dataset = _apply_filter_date_from(dataset, filters[:date_from])
        dataset = _apply_filter_date_to(dataset, filters[:date_to])
        dataset = _apply_filter_details_contains(dataset, filters[:details_contains])

        page = options.fetch(:page, 1).to_i
        per_page = options.fetch(:per_page, DEFAULT_PER_PAGE).to_i
        paginated_dataset = dataset.paginate(page, per_page)

        logs = paginated_dataset.all
        # rubocop:disable Layout/LineLength
        log_info("Fetched #{logs.size} security logs. Page: #{page}, PerPage: #{per_page}, TotalRecords: #{paginated_dataset.pagination_record_count}")
        # rubocop:enable Layout/LineLength

        {
          logs: logs,
          current_page: paginated_dataset.current_page,
          total_pages: paginated_dataset.page_count,
          total_entries: paginated_dataset.pagination_record_count
        }
      end
    end

    def find_all_with_details(filters = {})
      context = "finding ALL security logs with details and filters: #{filters}"
      with_error_handling(context) do
        dataset = SecurityLog.dataset

        default_order = [Sequel.desc(:log_timestamp), Sequel.desc(:log_id)]
        order_criteria = filters.fetch(:order, default_order)
        order_criteria = Array(order_criteria)
        dataset = dataset.order(*order_criteria) unless order_criteria.empty?

        dataset = _apply_filter_user_id(dataset, filters[:user_id])
        dataset = _apply_filter_username(dataset, filters[:username])
        dataset = _apply_filter_email(dataset, filters[:email])
        dataset = _apply_filter_action(dataset, filters[:action])
        dataset = _apply_filter_object(dataset, filters[:object])
        dataset = _apply_filter_date_from(dataset, filters[:date_from])
        dataset = _apply_filter_date_to(dataset, filters[:date_to])
        dataset = _apply_filter_details_contains(dataset, filters[:details_contains])

        logs = dataset.all
        log_info("Fetched #{logs.size} security logs for export.")
        logs
      end
    end

    private

    def find_or_create_special_user(username, email)
      user = UserDAO.find_one_by(username: username, email: email)
      user || UserDAO.create(username: username, email: email)
    end

    def create_log_entry(action:, object:, acting_user:, details: nil)
      context = "persisting security log for action '#{action}' on object '#{object}' by user '#{acting_user&.username || 'N/A'}'"
      with_error_handling(context) do
        unless acting_user.respond_to?(:id) && acting_user.respond_to?(:username)
          # rubocop:disable Layout/LineLength
          error_msg = "Cannot create security log: A valid User object (with id, username) is required for denormalization. Provided acting_user: #{acting_user.inspect}"
          # rubocop:enable Layout/LineLength
          log_error("#{context} - #{error_msg}")
          raise ArgumentError, error_msg
        end

        attributes = {
          action: action,
          object: object,
          user_id: acting_user.user_id,
          username: acting_user.username,
          email: acting_user&.email,
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

    def _apply_filter_user_id(dataset, user_id_param)
      return dataset if user_id_param.nil? || user_id_param.to_s.strip.empty?

      id_val = user_id_param.to_i
      return dataset unless id_val.positive?

      dataset.where(user_id: id_val)
    end

    def _apply_filter_username(dataset, username_param)
      username = username_param&.strip
      return dataset if username.nil? || username.empty?

      dataset.where(Sequel.ilike(:username, "%#{username}%"))
    end

    def _apply_filter_email(dataset, email_param)
      email = email_param&.strip
      return dataset if email.nil? || email.empty?

      dataset.where(Sequel.ilike(:email, "%#{email}%"))
    end

    def _apply_filter_action(dataset, action_param)
      action = action_param&.strip
      return dataset if action.nil? || action.empty?

      dataset.where(action: action)
    end

    def _apply_filter_object(dataset, object_param)
      object = object_param&.strip
      return dataset if object.nil? || object.empty?

      dataset.where(object: object)
    end

    def _apply_filter_details_contains(dataset, details_query_param)
      query = details_query_param&.strip
      return dataset if query.nil? || query.empty?

      dataset.where(Sequel.ilike(:details, "%#{query}%"))
    end

    def _apply_filter_date_from(dataset, date_from_param)
      parsed_date = _parse_date(date_from_param)
      return dataset unless parsed_date

      dataset.where { log_timestamp >= parsed_date.to_time.utc }
    end

    def _apply_filter_date_to(dataset, date_to_param)
      parsed_date = _parse_date(date_to_param)
      return dataset unless parsed_date

      end_of_day_timestamp = (parsed_date.to_time + (24 * 60 * 60) - 1).utc
      dataset.where { log_timestamp <= end_of_day_timestamp }
    end
  end
end
