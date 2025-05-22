# frozen_string_literal: true

require_relative '../helpers/auth_form_helpers'

# Module for routes within auth context
module AuthRoutes
  def self.registered(app)
    app.helpers AuthFormHelpers

    app.get '/login' do
      redirect '/profile' if logged_in?
      erb :'auth/login', layout: false
    end

    app.post '/login' do
      email = params[:email]
      password = params[:password]

      return render_login_error('Please fill in email and password.') if credentials_missing?(email, password)

      user = UserDAO.find_by_email(email)

      return render_login_error('Invalid email or password.') unless user&.is_active

      if UserDAO.locked?(user)
        return render_login_error('Your account has been blocked due to too many failed login attempts.')
      end

      authenticated_user = nil
      begin
        authenticated_user = AuthService.authenticate(user, password)
      rescue StandardError => e
        return render_login_error("An error occurred: #{e.message}")
      end

      if authenticated_user
        UserDAO.reset_lockout(user)
        establish_session(authenticated_user)
      else
        updated_user = UserDAO.increment_failed_attempts(user)

        if updated_user && updated_user.failed_login_attempts >= UserDAO::MAX_LOGIN_ATTEMPTS
          UserDAO.lock_user(updated_user)
          render_login_error("Incorrect password. Your account has been blocked due to too many failed attempts. Please try again in #{UserDAO::LOCKOUT_DURATION / 60} minutes.")
        else
          render_login_error('Invalid email or password.')
        end

      end
    end

    app.post '/logout' do
      session.clear
      flash[:success] = 'You have been successfully logged out.'
      redirect '/login'
    end

    app.get '/register' do
      erb :'auth/register', layout: false
    end

    app.post '/register' do
      validation_error = validate_registration_params
      if validation_error
        @error = validation_error
        return erb :'auth/register', layout: false
      end

      begin
        user = AuthService.register(params)
        session[:user_id] = user.user_id
        redirect '/profile'
      rescue StandardError => e
        @error = "Registration error: #{e.message}"
        erb :'auth/register', layout: false
      end
    end

    app.get '/forgot-password' do
      erb :'auth/forgot-password', layout: false
    end

    app.post '/forgot-password' do
      email = params[:email]
      user = UserDAO.find_by_email(email)

      if user && UserDAO.may_reset_password_based_on_user_object?(user)

        # TODO: Token generation + Mail

        UserDAO.record_password_reset_request(user[:user_id])
        puts "DEBUG: Passwort-Reset für #{email} angefordert und berechtigt. TODO: Token & Mail."
      else
        puts "DEBUG: Passwort-Reset für #{email} angefordert, aber nicht berechtigt oder Nutzer nicht gefunden."
      end
      flash[:notice] = "As long as there is an active account with this information an email has been sent. Please check your mail and spam folder."
      redirect '/login'
    end
  end
end
