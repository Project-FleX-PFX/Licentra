require_relative '../models/user_role'
require_relative 'base_dao'
require_relative 'user_role_logging'
require_relative 'user_role_error_handling'

class UserRoleDAO < BaseDAO
  class << self
    include UserRoleLogging
    include UserRoleErrorHandling

    # CREATE
    def create(user_id, role_id)
      context = "creating user role assignment for user_id #{user_id}, role_id #{role_id}"
      with_error_handling(context) do
        if exists?(user_id, role_id)
          log_info("Assignment already exists for User ID #{user_id}, Role ID #{role_id}")
          return find_assignment(user_id, role_id) # Gib das bestehende Objekt zurück
        end

        assignment = UserRole.create(user_id: user_id, role_id: role_id)
        log_assignment_created(user_id, role_id)
        assignment
      end
    end

    # READ
    def find_by_user(user_id)
      with_error_handling("finding role assignments for user_id #{user_id}") do
        assignments = UserRole.where(user_id: user_id).all
        log_assignments_for_user_fetched(user_id, assignments.size)
        assignments
      end
    end

    def find_by_role(role_id)
      with_error_handling("finding user assignments for role_id #{role_id}") do
        assignments = UserRole.where(role_id: role_id).all
        log_assignments_for_role_fetched(role_id, assignments.size)
        assignments
      end
    end

    def find_assignment(user_id, role_id)
      with_error_handling("finding specific assignment for user_id #{user_id}, role_id #{role_id}") do
        assignment = UserRole.first(user_id: user_id, role_id: role_id)
        log_assignment_found(user_id, role_id) if assignment
        assignment
      end
    end

    def find_assignment!(user_id, role_id)
      with_error_handling("finding specific assignment for user_id #{user_id}, role_id #{role_id}") do
        assignment = UserRole.first(user_id: user_id, role_id: role_id)
        unless assignment
          handle_record_not_found(user_id, role_id)
        end
        log_assignment_found(user_id, role_id)
        assignment
      end
    end

    def exists?(user_id, role_id)
       with_error_handling("checking existence for user_id #{user_id}, role_id #{role_id}") do
         UserRole.where(user_id: user_id, role_id: role_id).any?
       end
    end

    # DELETE
    def delete_assignment(user_id, role_id)
      context = "deleting assignment for user_id #{user_id}, role_id #{role_id}"
      with_error_handling(context) do
        count = UserRole.where(user_id: user_id, role_id: role_id).delete
        if count > 0
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
         count = UserRole.where(user_id: user_id).delete
         log_assignments_deleted_for_user(user_id, count)
         count
       end
    end

    def delete_by_role(role_id)
       context = "deleting all assignments for role_id #{role_id}"
       with_error_handling(context) do
         count = UserRole.where(role_id: role_id).delete
         log_assignments_deleted_for_role(role_id, count)
         count
       end
    end

  end
end
