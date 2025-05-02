# frozen_string_literal: true

# Helper methods for authentication
module AuthHelpers
  def current_user
    @current_user ||= session[:user_id] ? UserDAO.find(session[:user_id]) : nil
  end

  def logged_in?
    !current_user.nil?
  end

  def has_role?(role_name)
    return false unless logged_in?

    current_user.roles.any? { |role| role.role_name == role_name }
  end

  def admin?
    has_role?('Admin')
  end

  def require_login
    return if logged_in?

    session[:return_to] = request.path_info
    redirect '/login'
  end

  def require_role(role_name)
    require_login
    return if has_role?(role_name)

    halt 403, erb(:forbidden, layout: true, locals: { message: "You don't have permission to access this page." })
  end
end
