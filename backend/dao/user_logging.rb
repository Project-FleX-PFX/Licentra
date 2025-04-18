module UserLogging
    def log_user_created(user)
      log_info("User created: #{user.username} (ID: #{user.pk})")
    end
  
    def log_user_found(user)
      log_info("User found: #{user.username} (ID: #{user.pk})")
    end
  
    def log_user_not_found(id)
      log_warn("User with ID #{id} not found")
    end
  
    def log_user_found_by_criteria(criteria, user)
      log_info("User found by #{criteria.inspect}: #{user.username} (ID: #{user.pk})")
    end
  
    def log_user_found_by_username(username, user)
      log_info("User found by username '#{username}': #{user.username} (ID: #{user.pk})")
    end
  
    def log_user_found_by_email(email, user)
       log_info("User found by email '#{email}': #{user.username} (ID: #{user.pk})")
    end
  
    def log_user_not_found_by_criteria(criteria)
      log_warn("User not found for criteria: #{criteria.inspect}")
    end
  
    def log_user_not_found_by_username(username)
      log_warn("User not found with username: '#{username}'")
    end
  
    def log_user_not_found_by_email(email)
       log_warn("User not found with email: '#{email}'")
    end
  
    def log_validation_failed(user, context)
      log_warn("Validation failed while #{context} user '#{user.username || 'new'}': #{user.errors.inspect}")
    end
  
    def log_users_fetched(count)
      log_info("Fetched #{count} users")
    end
  
    def log_users_fetched_with_criteria(count, criteria)
      log_info("Fetched #{count} users with criteria: #{criteria.inspect}")
    end
  
    def log_user_updated(user)
      log_info("User updated: #{user.username} (ID: #{user.pk})")
    end
  
    def log_user_deleted(user)
      log_info("User deleted: #{user.username} (ID: #{user.pk})")
    end
  
    def log_user_roles_updated(user)
      # Sicherstellen, dass Rollen geladen sind, bevor man darauf zugreift
      log_info("Roles updated for user #{user.username} (ID: #{user.pk}) to: #{user.roles.map(&:role_name).join(', ')}")
    end
  
    def log_user_activated(user)
      log_info("User activated: #{user.username} (ID: #{user.pk})")
    end
  
     def log_user_deactivated(user)
      log_info("User deactivated: #{user.username} (ID: #{user.pk})")
    end
end
