require_relative '../models/role'
require_relative 'base_dao'
require_relative 'role_logging'
require_relative 'role_error_handling'

class RoleDAO < BaseDAO
  class << self
    include RoleLogging
    include RoleErrorHandling

    # CREATE
    def create(attributes)
      with_error_handling("creating role") do
        role = Role.new(attributes)
        if role.valid?
          role.save
          log_role_created(role)
          role
        else
          handle_validation_error(role, "creating role")
        end
      end
    end

    # READ
    def find!(id)
      with_error_handling("finding role with ID #{id}") do
        role = Role[id]
        unless role
          handle_record_not_found(id)
        end
        log_role_found(role)
        role
      end
    end

    def find(id)
      with_error_handling("finding role with ID #{id}") do
        role = Role[id]
        log_role_found(role) if role
        role
      end
    end

    def find_one_by(criteria)
      with_error_handling("finding role by criteria") do
        role = Role.first(criteria)
        log_role_found_by_criteria(criteria, role) if role
        role
      end
    end

    def find_one_by!(criteria)
      with_error_handling("finding role by criteria") do
        role = find_one_by(criteria)
        unless role
          handle_record_not_found_by_criteria(criteria)
        end
        role
      end
    end

    def find_by_name(name)
      return nil if name.nil? || name.empty?
      role = find_one_by(role_name: name)
      log_role_found_by_name(name, role) if role
      role
    end

    def find_by_name!(name)
       with_error_handling("finding role by name '#{name}'") do
         role = find_by_name(name)
         unless role
           handle_record_not_found_by_name(name)
         end
         role
       end
    end

    def all(options = {})
      with_error_handling("fetching all roles") do
        dataset = Role.dataset
        dataset = dataset.where(options[:where]) if options[:where]
        dataset = dataset.order(options[:order]) if options[:order]
        roles = dataset.all
        log_roles_fetched(roles.size)
        roles
      end
    end

    def where(criteria)
      with_error_handling("filtering roles by criteria") do
        roles = Role.where(criteria).all
        log_roles_fetched_with_criteria(roles.size, criteria)
        roles
      end
    end

    # UPDATE
    def update(id, attributes)
      with_error_handling("updating role with ID #{id}") do
        role = find!(id)
        role.update(attributes)
        log_role_updated(role)
        role
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, "updating role with ID #{id}")
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting role with ID #{id}") do
        role = find!(id)
        if role.users_dataset.any?
          raise DatabaseError, "Cannot delete role '#{role.role_name}' (ID: #{id}) because it is still assigned to users."
        end

        role.destroy
        log_role_deleted(role)
        true
      end
    end

  end
end
