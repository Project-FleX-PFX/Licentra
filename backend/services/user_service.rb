# frozen_string_literal: true

require_relative '../dao/user_dao'
require_relative '../dao/role_dao'
require_relative '../dao/user_credential_dao'
require_relative '../dao/security_log_dao'
require_relative '../dao/license_assignment_dao'
require_relative '../dao/password_reset_token_dao'
require_relative '../dao/user_role_dao'
require_relative '../models/user'

class UserService
  class ServiceError < StandardError; end
  class UserManagementError < ServiceError; end
  class NotFoundError < ServiceError; end
  class NotAuthorizedError < ServiceError; end
  class AdminProtectionError < UserManagementError; end

  def self.create_user_as_admin(params, admin_user)
    _authorize_admin(admin_user)

    username_val = params[:username]&.strip
    email_val = params[:email]&.strip
    password_val = params[:new_password]

    raise UserManagementError, 'Username is required.' if username_val.nil? || username_val.empty?
    raise UserManagementError, 'Email is required.' if email_val.nil? || email_val.empty?
    raise UserManagementError, 'Password is required for new user.' if password_val.nil? || password_val.empty?

    raise UserManagementError, "Username '#{username_val}' already exists." if UserDAO.find_by_username(username_val)
    raise UserManagementError, "Email '#{email_val}' already exists." if UserDAO.find_by_email(email_val)

    role_ids_from_form = Array(params[:role_ids]).map(&:to_i).uniq
    raise UserManagementError, 'At least one role must be selected for a new user.' if role_ids_from_form.empty?

    role_ids_from_form.each do |rid|
      raise UserManagementError, "Invalid Role ID: #{rid} provided." unless RoleDAO.find(rid)
    end

    user_attributes = {
      username: username_val,
      email: email_val,
      first_name: params[:first_name]&.strip,
      last_name: params[:last_name]&.strip,
      is_active: params[:is_active] == 'true'
    }

    new_user = nil
    DB.transaction do
      new_user = UserDAO.create(user_attributes)
      unless new_user&.persisted? && new_user.valid?
        error_messages = new_user&.errors&.full_messages&.join(', ') || 'Unknown reason.'
        raise UserManagementError, "Failed to create user base record: #{error_messages}"
      end

      UserCredentialDAO.create_for_user(new_user.user_id, password_val)
      UserRoleDAO.set_user_roles(new_user.user_id, role_ids_from_form)
      new_user.refresh
    end

    SecurityLogDAO.log_user_created(acting_user: admin_user, created_user: new_user)
    new_user
  rescue DAO::AdminProtectionError => e
    raise AdminProtectionError, e.message
  rescue Sequel::ValidationFailed => e
    raise UserManagementError, "User creation failed due to validation: #{e.errors.full_messages.join(', ')}"
  rescue UserManagementError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in create_user_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise UserManagementError, "An unexpected error occurred while creating the user: #{e.message}"
  end

  def self.update_user_details_as_admin(target_user_id, params, admin_user)
    _authorize_admin(admin_user)
    user_to_update = _find_user_or_fail(target_user_id)

    update_attrs = {}

    if params.key?('username')
      val = params['username']&.strip
      raise UserManagementError, 'Username cannot be empty.' if val.nil? || val.empty?
      if val != user_to_update.username && UserDAO.username_exists_for_other_user?(val, target_user_id)
        raise UserManagementError, "Username '#{val}' already exists."
      end

      update_attrs[:username] = val
    end

    if params.key?('email')
      val = params['email']&.strip
      raise UserManagementError, 'Email cannot be empty.' if val.nil? || val.empty?
      raise UserManagementError, "Invalid email format for '#{val}'." unless val.match?(URI::MailTo::EMAIL_REGEXP)
      if val != user_to_update.email && UserDAO.email_exists_for_other_user?(val, target_user_id)
        raise UserManagementError, "Email '#{val}' already exists."
      end

      update_attrs[:email] = val
    end

    update_attrs[:first_name] = params['first_name']&.strip if params.key?('first_name')
    update_attrs[:last_name] = params['last_name']&.strip if params.key?('last_name')

    if params.key?('is_active')
      update_attrs[:is_active] = (params['is_active'] == 'true')
      if user_to_update.admin? && update_attrs[:is_active] == false && UserRoleDAO.count_admins <= 1
        raise AdminProtectionError, 'Cannot deactivate the last administrator account.'
      end
    end

    return user_to_update.refresh if update_attrs.empty?

    changes_descriptions = []
    update_attrs.each do |key, new_value|
      old_value = user_to_update.send(key)
      if old_value.to_s != new_value.to_s
        formatted_key = key.to_s.split('_').map(&:capitalize).join(' ')
        changes_descriptions << "#{formatted_key} changed from '#{old_value}' to '#{new_value}'"
      end
    end

    updated_user_object = UserDAO.update(target_user_id, update_attrs)
    raise UserManagementError, "Failed to update user details for #{target_user_id}." unless updated_user_object

    if changes_descriptions.any?
      SecurityLogDAO.log_user_updated(
        acting_user: admin_user,
        updated_user: updated_user_object.refresh,
        changes_description: changes_descriptions.join('; ')
      )
    end
    updated_user_object.refresh
  rescue Sequel::ValidationFailed => e
    raise UserManagementError, "User update failed due to validation: #{e.errors.full_messages.join(', ')}"
  rescue UserManagementError, AdminProtectionError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in update_user_details_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise UserManagementError, "An unexpected error occurred while updating user details: #{e.message}"
  end

  def self.manage_user_roles_as_admin(target_user_id, new_role_ids_from_form, admin_user)
    _authorize_admin(admin_user)
    user_to_update = _find_user_or_fail(target_user_id)

    new_role_ids = Array(new_role_ids_from_form).map(&:to_i).uniq
    raise UserManagementError, 'At least one role must be selected when managing roles.' if new_role_ids.empty?

    new_role_ids.each do |rid|
      raise UserManagementError, "Invalid Role ID: #{rid} provided for assignment." unless RoleDAO.find(rid)
    end

    current_roles_names_sorted = user_to_update.roles.map(&:role_name).sort.join(', ')

    UserRoleDAO.set_user_roles(target_user_id, new_role_ids)

    user_to_update.refresh
    new_roles_names_sorted = user_to_update.roles.map(&:role_name).sort.join(', ')

    if current_roles_names_sorted != new_roles_names_sorted
      SecurityLogDAO.log_user_updated(
        acting_user: admin_user,
        updated_user: user_to_update,
        changes_description: "Roles changed from [#{current_roles_names_sorted}] to [#{new_roles_names_sorted}]."
      )
    end
    user_to_update
  rescue DAO::AdminProtectionError => e
    raise AdminProtectionError, e.message
  rescue UserManagementError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in manage_user_roles_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise UserManagementError, "An unexpected error occurred while managing user roles: #{e.message}"
  end

  def self.reset_user_password_as_admin(target_user_id, new_password, admin_user)
    _authorize_admin(admin_user)
    user_to_update = _find_user_or_fail(target_user_id)

    raise UserManagementError, 'New password cannot be empty.' if new_password.nil? || new_password.empty?

    updated_credential = UserCredentialDAO.update_password(target_user_id, new_password)
    raise UserManagementError, "Failed to reset password for user #{target_user_id}." unless updated_credential

    SecurityLogDAO.log_user_updated(
      acting_user: admin_user,
      updated_user: user_to_update.refresh,
      changes_description: 'Password reset by administrator.'
    )
    true
  rescue UserCredential::PasswordPolicyError => e
    raise UserManagementError, "Password reset failed: #{e.message}"
  rescue UserManagementError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in reset_user_password_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise UserManagementError, "An unexpected error occurred while resetting the password: #{e.message}"
  end

  def self.lock_user_as_admin(target_user_id, admin_user)
    _authorize_admin(admin_user)
    user_to_lock = _find_user_or_fail(target_user_id)

    raise UserManagementError, 'Cannot lock your own admin account.' if user_to_lock.user_id == admin_user.user_id
    raise UserManagementError, 'Account is already locked.' if UserDAO.locked?(user_to_lock)
    raise UserManagementError, "Failed to lock user account #{target_user_id}." unless UserDAO.lock_user(user_to_lock)

    true
  rescue UserManagementError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in lock_user_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise UserManagementError, "An unexpected error occurred while locking the user: #{e.message}"
  end

  def self.unlock_user_as_admin(target_user_id, admin_user)
    _authorize_admin(admin_user)
    user_to_unlock = _find_user_or_fail(target_user_id)

    unless UserDAO.reset_lockout(user_to_unlock)
      raise UserManagementError, "Failed to unlock user account #{target_user_id}."
    end

    SecurityLogDAO.log_user_updated(
      acting_user: admin_user,
      updated_user: user_to_unlock.refresh,
      changes_description: 'Account unlocked by administrator.'
    )
    true
  rescue UserManagementError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in unlock_user_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise UserManagementError, "An unexpected error occurred while unlocking the user: #{e.message}"
  end

  def self.delete_user_as_admin(target_user_id, admin_user)
    _authorize_admin(admin_user)
    user_to_delete = _find_user_or_fail(target_user_id)

    raise UserManagementError, 'Cannot delete your own admin account.' if user_to_delete.user_id == admin_user.user_id

    if UserRoleDAO.is_user_admin?(target_user_id) && UserRoleDAO.count_admins <= 1
      raise AdminProtectionError, 'Cannot delete the last administrator account.'
    end

    deleted_username = user_to_delete.username
    deleted_id = user_to_delete.user_id

    DB.transaction do
      LicenseAssignmentDAO.model_class.where(user_id: target_user_id).delete
      PasswordResetTokenDAO.delete_by_user(target_user_id)
      UserRoleDAO.delete_by_user(target_user_id)

      # UserCredential wird durch `plugin :association_dependencies, credential: :delete` im User-Modell
      # automatisch gelöscht, wenn UserDAO.delete den User-Datensatz löscht.

      unless UserDAO.delete(target_user_id)
        raise UserManagementError, "Failed to delete user (ID: #{target_user_id}) using UserDAO."
      end

      SecurityLogDAO.log_user_deleted(
        acting_user: admin_user,
        deleted_user_username: deleted_username,
        deleted_user_id: deleted_id
      )
      true
    end
  rescue DAO::AdminProtectionError => e
    raise AdminProtectionError, e.message
  rescue UserManagementError, AdminProtectionError => e
    raise e
  rescue StandardError => e
    puts "ERROR: Unexpected error in delete_user_as_admin: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    raise UserManagementError, "An unexpected error occurred while deleting the user: #{e.message}"
  end

  private_class_method

  def self._authorize_admin(user)
    raise NotAuthorizedError, 'Admin privileges required.' unless user&.admin?
  end

  def self._find_user_or_fail(user_id)
    UserDAO.find_by_id_with_roles!(user_id)
  rescue DAO::RecordNotFound
    raise NotFoundError, "User (ID: #{user_id}) not found."
  end
end
