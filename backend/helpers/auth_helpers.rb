# frozen_string_literal: true

# Helper methods for authentication
module AuthHelpers
  def current_user
    @current_user ||= session[:user_id] ? UserDAO.find(session[:user_id]) : nil
  end

  def logged_in?
    !current_user.nil?
  end

  def role?(role_name)
    return false unless logged_in?

    current_user.role?(role_name)
  end

  def admin?
    role?('Admin')
  end

  def require_login
    return if logged_in?

    session[:return_to] = request.path_info
    redirect '/login'
  end

  def require_role(role_name)
    require_login
    return if role?(role_name)

    halt 403, erb(:'errors/403',
                  locals: { message: "You don't have permission to access this page." },
                  layout: :'layouts/application')
  end
end
