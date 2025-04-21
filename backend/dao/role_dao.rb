# frozen_string_literal: true

require_relative '../models/role'
require_relative 'base_dao'
require_relative 'concerns/crud_operations'
require_relative 'role_logging'
require_relative 'role_error_handling'
require_relative 'user_role_dao'

# Data Access Object for Role entities, handling database operations
class RoleDAO < BaseDAO
  def self.model_class
    Role
  end

  def self.primary_key
    :role_id
  end

  include CrudOperations

  class << self
    include RoleLogging
    include RoleErrorHandling
  end

  class << self
    def find_by_name(name)
      return nil if name.nil? || name.empty?

      role = find_one_by(role_name: name)
      log_role_found_by_name(name, role) if role
      role
    end

    def find_by_name!(name)
      find_by_name(name) || handle_record_not_found_by_name(name)
    end

    def delete(id)
      context = "deleting role with ID #{id}"
      with_error_handling(context) do
        if UserRoleDAO.find_by_role(id).any?
          role = find!(id)
          raise DatabaseError,
                "Cannot delete role '#{role.role_name}' (ID: #{id}) because it is still assigned to users."
        end

        UserRoleDAO.delete_by_role(id)

        super(id)
      end
    end
  end
end
