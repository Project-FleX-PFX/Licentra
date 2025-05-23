# frozen_string_literal: true

require_relative '../models/user'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'user_logging'
require_relative 'user_error_handling'
require_relative 'role_dao'
require_relative 'user_role_dao'

# Data Access Object for User entities, handling database operations
class UserDAO < BaseDAO
  def self.model_class
    User
  end

  def self.primary_key
    :user_id
  end

  include CrudOperations

  class << self
    include UserLogging
    include UserErrorHandling
  end

  MAX_LOGIN_ATTEMPTS = 3
  LOCKOUT_DURATION = 15 * 60

  class << self
    # User lookup methods
    def find_by_username(username)
      return nil if username.nil? || username.empty?

      user = find_one_by(Sequel.function(:lower, :username) => username.downcase)
      log_user_found_by_username(username, user) if user
      user
    end

    def find_by_username!(username)
      find_by_username(username) || handle_record_not_found_by_username(username)
    end

    def find_by_email(email)
      return nil if email.nil? || email.empty?

      user = find_one_by(Sequel.function(:lower, :email) => email.downcase)
      log_user_found_by_email(email, user) if user
      user
    end

    def find_by_email!(email)
      find_by_email(email) || handle_record_not_found_by_email(email)
    end

    def find_by_id(id_value)
      return nil if id_value.nil?
      context = "finding user by ID #{id_value}"

      with_error_handling(context) do
        user = find_one_by(self.primary_key => id_value)
        log_info("User lookup by ID: #{id_value}, Found: #{!user.nil?}") if user
        user
      end
    end

    # Advanced query methods
    def where(criteria)
      context = "filtering #{model_class_name_plural} by criteria"
      with_error_handling(context) do
        dataset = build_query_from_criteria(criteria)
        instances = dataset.all
        log_fetched_with_criteria(instances.size, criteria)
        instances
      end
    end

    def find_active_users(options = {})
      active_criteria = { is_active: true }
      all(options.merge(where: options.fetch(:where, {}).merge(active_criteria)))
    end

    def find_inactive_users(options = {})
      inactive_criteria = { is_active: false }
      all(options.merge(where: options.fetch(:where, {}).merge(inactive_criteria)))
    end

    def locked?(user)
      return false unless user&.locked_at

      if LOCKOUT_DURATION && user.locked_at < (Time.now - LOCKOUT_DURATION)
        reset_lockout(user)
        return false
      end

      true
    end

    def increment_failed_attempts(user)
      return nil unless user

      update_payload = { failed_login_attempts: Sequel.+(:failed_login_attempts, 1) }
      action_description = 'increment failed login attempts'

      updated_user = _perform_atomic_user_update(user, update_payload, action_description)

      if updated_user
        log_info("Incremented failed attempts for user #{updated_user.email}. New count: #{updated_user.failed_login_attempts}")
      end
      updated_user
    end

    def lock_user(user)
      return nil unless user

      update_payload = { locked_at: Time.now }
      action_description = 'lock account'

      updated_user = _perform_atomic_user_update(user, update_payload, action_description)

      log_info("Locked account for user #{updated_user.email}") if updated_user
      updated_user
    end

    def reset_lockout(user)
      return nil unless user
      return user if user.failed_login_attempts.zero? && user.locked_at.nil?

      update_payload = { failed_login_attempts: 0, locked_at: nil }
      action_description = 'reset lockout status'

      updated_user = _perform_atomic_user_update(user, update_payload, action_description)

      log_info("Reset lockout status for user #{updated_user.email}") if updated_user
      updated_user
    end

    # User state management
    def activate_user(id)
      update_user_state(id, true, 'activating')
    end

    def deactivate_user(id)
      update_user_state(id, false, 'deactivating')
    end

    # Role management
    def assign_role_by_name(user_id, role_name)
      modify_user_role(user_id, role_name) do |user, role|
        user.add_role(role)
      end
    end

    def remove_role_by_name(user_id, role_name)
      modify_user_role(user_id, role_name) do |user, role|
        user.remove_role(role)
      end
    end

    def set_roles_by_name(user_id, role_names)
      context = "setting roles for user ID #{user_id}"
      with_error_handling(context) do
        user = find!(user_id)
        roles_to_set = role_names.map { |name| RoleDAO.find_by_name!(name) }
        user.remove_all_roles
        roles_to_set.each { |role| user.add_role(role) }
        user.refresh
        log_user_roles_updated(user)
        user
      end
    end

    def delete(id)
      context = "deleting user with ID #{id}"
      with_error_handling(context) do
        user = find!(id)
        user.remove_all_roles
        user.destroy
        log_deleted(user)
        true
      end
    end

    def may_reset_password_based_on_user_object?(user_object)
      context = "checking if user #{user_object[:user_id]} may reset password"
      with_error_handling(context) do
        return false unless user_object && user_object[:is_active]

        last_reset_time = user_object[:last_password_reset_requested_at]
        return true if last_reset_time.nil?

        (Time.now - last_reset_time) > (24 * 60 * 60)
      end
    end

    def record_password_reset_request(user_id)
      context = "recording password reset request for user #{user_id}"
      with_error_handling(context) do
        DB[:users].where(user_id: user_id).update(last_password_reset_requested_at: Time.now)
      end
    end

    private

    # Helper methods to reduce complexity
    def build_query_from_criteria(criteria)
      dataset = model_class.dataset
      processed_criteria = criteria.dup

      # Handle case-insensitive username search
      if processed_criteria.key?(:username) && processed_criteria[:username].is_a?(String)
        dataset = apply_username_filter(dataset, processed_criteria)
      end

      # Apply remaining criteria
      dataset = dataset.where(processed_criteria) unless processed_criteria.empty?
      dataset.order(:username)
    end

    def apply_username_filter(dataset, criteria)
      username_value = criteria.delete(:username).downcase
      username_condition = { Sequel.function(:lower, :username) => username_value }
      dataset.where(username_condition)
    end

    def update_user_state(id, is_active, action_name)
      context = "#{action_name} user with ID #{id}"
      with_error_handling(context) do
        user = update(id, is_active: is_active)
        is_active ? log_user_activated(user) : log_user_deactivated(user)
        user
      end
    end

    def modify_user_role(user_id, role_name)
      context = "modifying role '#{role_name}' for user ID #{user_id}"
      with_error_handling(context) do
        user = find!(user_id)
        role = RoleDAO.find_by_name!(role_name)

        yield(user, role)

        user.refresh
        log_user_roles_updated(user)
        user
      end
    end

    def _perform_atomic_user_update(user_instance, update_payload, action_description_for_log_and_context)
      context = "#{action_description_for_log_and_context.capitalize} for user ID #{user_instance.pk}"

      with_error_handling(context) do
        updated_rows = model_class.where(primary_key => user_instance.pk).update(update_payload)

        if updated_rows == 1
          user_instance.refresh
          user_instance
        else
          log_error("Failed to #{action_description_for_log_and_context.downcase} for user ID #{user_instance.pk}. No rows updated.")
          nil
        end
      end
    end

    def may_request_password_reset?(user)
      return false unless user

      is_active = user[:is_active]
      last_request_time = user[:last_password_reset_requested_at]

      return false unless is_active

      if last_request_time.nil?
        true
      else
        one_day_ago = Time.now - (24 * 60 * 60)
        last_request_time < one_day_ago
      end
    end
  end
end
