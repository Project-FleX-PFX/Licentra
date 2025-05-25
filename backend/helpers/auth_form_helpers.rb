# frozen_string_literal: true

# Helper methods for Authetication Forms
module AuthFormHelpers
  def credentials_missing?(email, password)
    email.nil? || email.empty? || password.nil? || password.empty?
  end

  def establish_session(user)
    session[:user_id] = user.user_id
    redirect_url = session[:return_to] || '/'
    session.delete(:return_to)
    redirect redirect_url
  end

  def render_login_error(message)
    @error = message
    erb :'auth/login', layout: :'layouts/auth'
  end

  def render_registration_error(message)
    @error = message
    erb :'auth/register', layout: :'layouts/auth'
  end

  def required_fields_missing?
    [params[:username], params[:first_name], params[:last_name],
     params[:email], params[:password], params[:password_confirmation]].any?(&:empty?)
  end

  def passwords_dont_match?
    params[:password] != params[:password_confirmation]
  end

  def username_taken?
    UserDAO.find_by_username(params[:username])
  end

  def email_taken?
    UserDAO.find_by_email(params[:email])
  end

  def validate_registration_params
    return 'Please fill in all fields.' if required_fields_missing?
    return 'Passwords do not match.' if passwords_dont_match?
    return 'Username is already taken.' if username_taken?
    return 'Email address is already registered.' if email_taken?

    nil
  end
end
