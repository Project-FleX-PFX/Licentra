require_relative '../models/user'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'user_logging'
require_relative 'user_error_handling'
require_relative 'role_dao'
require_relative 'user_role_dao'

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

  class << self

    def find_by_username(username)
      return nil if username.nil? || username.empty?
      user = find_one_by(username: username)
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
      
    def where(criteria)
      context = "filtering #{model_class_name_plural} by criteria"
      with_error_handling(context) do
        dataset = model_class.dataset
        processed_criteria = criteria.dup

        if processed_criteria.key?(:username) && processed_criteria[:username].is_a?(String)
          username_value = processed_criteria.delete(:username).downcase
          username_condition = { Sequel.function(:lower, :username) => username_value }
          dataset = dataset.where(username_condition)
        end

        dataset = dataset.where(processed_criteria) unless processed_criteria.empty?
        dataset = dataset.order(:username)
        instances = dataset.all
        log_fetched_with_criteria(instances.size, criteria)
        instances
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

    def find_active_users(options = {})
      active_criteria = { is_active: true }
      all(options.merge(where: options.fetch(:where, {}).merge(active_criteria)))
    end

    def find_inactive_users(options = {})
      inactive_criteria = { is_active: false }
      all(options.merge(where: options.fetch(:where, {}).merge(inactive_criteria)))
    end

    def activate_user(id)
       context = "activating user with ID #{id}"
       with_error_handling(context) do
         user = update(id, is_active: true)
         log_user_activated(user)
         user
       end
    end

    def deactivate_user(id)
       context = "deactivating user with ID #{id}"
       with_error_handling(context) do
         user = update(id, is_active: false)
         log_user_deactivated(user)
         user
       end
    end

    def assign_role_by_name(user_id, role_name)
       context = "assigning role '#{role_name}' to user ID #{user_id}"
       with_error_handling(context) do
         user = find!(user_id)
         role = RoleDAO.find_by_name!(role_name)
         user.add_role(role)
         user.refresh
         log_user_roles_updated(user)
         user
       end
     end

     def remove_role_by_name(user_id, role_name)
       context = "removing role '#{role_name}' from user ID #{user_id}"
        with_error_handling(context) do
          user = find!(user_id)
          role = RoleDAO.find_by_name!(role_name)
          user.remove_role(role)
          user.refresh
          log_user_roles_updated(user)
          user
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

  end
end
