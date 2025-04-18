require_relative '../models/user'
require_relative 'base_dao'
require_relative 'user_logging'
require_relative 'user_error_handling'
require_relative 'role_dao'

class UserDAO < BaseDAO
  class << self
    include UserLogging
    include UserErrorHandling

    MODEL_PK = :user_id

    # CREATE
    def create(attributes)
      with_error_handling("creating user") do
        user = User.new(attributes)
        if user.valid?
          user.save
          log_user_created(user)
          user
        else
          handle_validation_error(user, "creating user")
        end
      end
    end

    # READ
    def find!(id)
      with_error_handling("finding user with ID #{id}") do
        user = User[MODEL_PK => id]
        user = User.eager(:credential, :roles)[MODEL_PK => id]
        unless user
          handle_record_not_found(id)
        end
        log_user_found(user)
        user
      end
    end

    def find(id)
       with_error_handling("finding user with ID #{id}") do
         user = User[MODEL_PK => id]
         log_user_found(user) if user
         user
       end
     end

    def find_one_by(criteria)
      with_error_handling("finding user by criteria") do
        user = User.first(criteria)
        log_user_found_by_criteria(criteria, user) if user
        user
      end
    end

     def find_one_by!(criteria)
      with_error_handling("finding user by criteria") do
        user = find_one_by(criteria)
        unless user
          handle_record_not_found_by_criteria(criteria)
        end
        user
      end
    end

    def find_by_username(username)
       return nil if username.nil? || username.empty?
       user = find_one_by(username: username)
       log_user_found_by_username(username, user) if user
       user
     end

    def find_by_username!(username)
        with_error_handling("finding user by username '#{username}'") do
          user = find_by_username(username)
          unless user
            handle_record_not_found_by_username(username)
          end
          user
        end
     end

    def find_by_email(email)
       return nil if email.nil? || email.empty?
       user = User.first(Sequel.function(:lower, :email) => email.downcase)
       log_user_found_by_email(email, user) if user
       user
     end

     def find_by_email!(email)
        with_error_handling("finding user by email '#{email}'") do
          user = find_by_email(email)
          unless user
            handle_record_not_found_by_email(email)
          end
          user
        end
     end

    def all(options = {})
       with_error_handling("fetching all users") do
         dataset = User.dataset
         dataset = dataset.where(options[:where]) if options[:where]
         dataset = dataset.order(options[:order]) if options[:order]
         dataset = dataset.eager(:roles) if options[:eager_roles]
         dataset = dataset.eager(:credential) if options[:eager_credential]
         users = dataset.all
         log_users_fetched(users.size)
         users
       end
     end

     def where(criteria)
       with_error_handling("filtering users by criteria") do
         if criteria.key?(:username) && criteria[:username].is_a?(String)
            users = User.where(Sequel.function(:lower, :username) => criteria[:username].downcase).all
         else
            users = User.where(criteria).all
         end
         log_users_fetched_with_criteria(users.size, criteria)
         users
       end
     end

    # UPDATE
    def update(id, attributes)
      with_error_handling("updating user with ID #{id}") do
        user = find!(id)
        user.update(attributes)
        log_user_updated(user)
        user
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, "updating user with ID #{id}")
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting user with ID #{id}") do
        user = find!(id)

        user.remove_all_roles

        user.destroy
        log_user_deleted(user)
        true
      end
    end

    # SPECIAL QUERIES

    def find_active_users(options = {})
      active_criteria = { is_active: true }
      merged_criteria = options.fetch(:where, {}).merge(active_criteria)
      all(options.merge(where: merged_criteria))
    end

    def find_inactive_users(options = {})
       inactive_criteria = { is_active: false }
       merged_criteria = options.fetch(:where, {}).merge(inactive_criteria)
       all(options.merge(where: merged_criteria))
    end

     def activate_user(id)
        with_error_handling("activating user with ID #{id}") do
          user = update(id, is_active: true)
          log_user_activated(user)
          user
        end
     end

     def deactivate_user(id)
        with_error_handling("deactivating user with ID #{id}") do
          user = update(id, is_active: false)
          log_user_deactivated(user)
          user
        end
     end

    def assign_role_by_name(user_id, role_name)
        with_error_handling("assigning role '#{role_name}' to user ID #{user_id}") do
          user = find!(user_id)
          role = RoleDAO.find_by_name!(role_name)
          user.add_role(role)
          user.refresh
          log_user_roles_updated(user.reload)
          user
        end
     end

     def remove_role_by_name(user_id, role_name)
         with_error_handling("removing role '#{role_name}' from user ID #{user_id}") do
           user = find!(user_id)
           role = RoleDAO.find_by_name!(role_name)
           user.remove_role(role)
           user.refresh
           log_user_roles_updated(user.reload)
           user
        end
      end

     def set_roles_by_name(user_id, role_names)
        with_error_handling("setting roles for user ID #{user_id}") do
          user = find!(user_id)
          roles_to_set = role_names.map { |name| RoleDAO.find_by_name!(name) }
          user.remove_all_roles
          roles_to_set.each { |role| user.add_role(role) }
          user.refresh
          log_user_roles_updated(user.reload)
          user
        end
     end

  end
end
