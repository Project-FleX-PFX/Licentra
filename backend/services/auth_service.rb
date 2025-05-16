# frozen_string_literal: true

# Service class which handles auth
class AuthService
  def self.authenticate(user, password)
    return user if user&.is_active && user.authenticate(password)

    nil
  end

  def self.register(params)
    is_first_user = UserDAO.all.empty?

    user = create_user_from_params(params)
    assign_roles(user, is_first_user)

    user
  end

  def self.credentials_invalid?(email, password)
    email.nil? || email.empty? || password.nil? || password.empty?
  end

  def self.create_user_from_params(params)
    user = User.new(
      username: params[:username],
      email: params[:email],
      first_name: params[:first_name],
      last_name: params[:last_name],
      is_active: true,
      credential_attributes: { password: params[:password] }
    )

    user.save_changes
    user
  end

  def self.assign_roles(user, is_first_user)
    if is_first_user
      admin_role = RoleDAO.find_by_name('Admin')
      user.add_role(admin_role) if admin_role
    end

    user_role = RoleDAO.find_by_name('User')
    user.add_role(user_role) if user_role
  end
end
