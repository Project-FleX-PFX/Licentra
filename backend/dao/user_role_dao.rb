# frozen_string_literal: true

require_relative '../models/user_role'
require_relative 'base_dao'
require_relative 'user_role_logging'
require_relative 'user_role_error_handling'

# Data Access Object for UserRole entities, handling database operations
class UserRoleDAO < BaseDAO
  class << self
    include UserRoleLogging
    include UserRoleErrorHandling

    def model_class
      UserRole
    end

    # CREATE
    def create(user_id, role_id)
      context = "creating user role assignment for user_id #{user_id}, role_id #{role_id}"
      with_error_handling(context) do
        assignment = model_class.create(user_id: user_id, role_id: role_id)
        log_assignment_created(user_id, role_id)
        assignment
      end
    end

    # READ
    def find_by_user(user_id)
      context = "finding role assignments for user_id #{user_id}"
      with_error_handling(context) do
        assignments = model_class.where(user_id: user_id).all
        log_assignments_for_user_fetched(user_id, assignments.size)
        assignments
      end
    end

    def find_by_role(role_id)
      context = "finding user assignments for role_id #{role_id}"
      with_error_handling(context) do
        assignments = model_class.where(role_id: role_id).all
        log_assignments_for_role_fetched(role_id, assignments.size)
        assignments
      end
    end

    def find_assignment(user_id, role_id)
      context = "finding specific assignment for user_id #{user_id}, role_id #{role_id}"
      with_error_handling(context) do
        assignment = model_class.first(user_id: user_id, role_id: role_id)
        log_assignment_found(user_id, role_id) if assignment
        assignment
      end
    end

    def find_assignment!(user_id, role_id)
      context = "finding specific assignment for user_id #{user_id}, role_id #{role_id}"
      with_error_handling(context) do
        assignment = model_class.first(user_id: user_id, role_id: role_id)
        handle_record_not_found(user_id, role_id) unless assignment
        log_assignment_found(user_id, role_id)
        assignment
      end
    end

    def exists?(user_id, role_id)
      context = "checking existence for user_id #{user_id}, role_id #{role_id}"
      with_error_handling(context) do
        model_class.where(user_id: user_id, role_id: role_id).any?
      end
    end


    # DELETE
    def delete_assignment(user_id, role_id)
      context = "deleting assignment for user_id #{user_id}, role_id #{role_id}"
      with_error_handling(context) do
        # Check if this is an admin role and if it's the last admin
        if is_admin_role?(role_id) && is_user_admin?(user_id) && count_admins <= 1
          log_admin_protection_deleting_admin_for_user(user_id)
          handle_admin_protection(context)
        end

        count = model_class.where(user_id: user_id, role_id: role_id).delete
        if count.positive?
          log_assignment_deleted(user_id, role_id)
          true
        else
          false
        end
      end
    end

    def delete_by_user(user_id)
      context = "deleting all assignments for user_id #{user_id}"
      with_error_handling(context) do
        # Check if user is an admin and if it's the last admin
        if is_user_admin?(user_id) && count_admins <= 1
          log_admin_protection_deleting_assignments_for_user(user_id)
          handle_admin_protection(context)
        end

        count = model_class.where(user_id: user_id).delete
        log_assignments_deleted_for_user(user_id, count)
        count
      end
    end

    def delete_by_role(role_id)
      context = "deleting all assignments for role_id #{role_id}"
      with_error_handling(context) do
        # Check if this is an admin role
        if is_admin_role?(role_id)
          log_admin_protection_deleting_admin_role
          handle_admin_protection(context)
        end

        count = model_class.where(role_id: role_id).delete
        log_assignments_deleted_for_role(role_id, count)
        count
      end
    end

    # Admin protection helper methods

    # Check if a role is the admin role
    def is_admin_role?(role_id)
      context = "checking if role_id #{role_id} is admin role"
      with_error_handling(context) do
        role = RoleDAO.find(role_id)
        role && role.role_name.downcase == 'admin'
      end
    end

    # Check if a user has the admin role
    def is_user_admin?(user_id)
      context = "checking if user_id #{user_id} has admin role (optimized)"
      with_error_handling(context) do
        model_class.dataset
                   .join(:roles, role_id: :role_id)
                   .where(Sequel[:user_roles][:user_id] => user_id, Sequel[:roles][:role_name] => 'Admin')
                   .any?
      end
    end

    # Get the ID of the admin role
    def get_admin_role_id
      context = "getting admin role ID"
      with_error_handling(context) do
        role = RoleDAO.find_by_name('Admin')
        role ? role.id : nil
      end
    end


    # Count the number of users with a specific role
    def count_users_with_role(role_id)
      context = "counting users with role_id #{role_id}"
      with_error_handling(context) do
        model_class.where(role_id: role_id).count
      end
    end

    # Count the number of users with admin role
    def count_admins
      context = "counting admin users (optimized)"
      with_error_handling(context) do
        model_class.dataset # Beginnt mit der user_roles Tabelle
                   .join(:roles, role_id: :role_id)
                   .where(Sequel[:roles][:role_name] => 'Admin')
                   .count
      end
    end

  end
end
