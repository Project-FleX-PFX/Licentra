# frozen_string_literal: true

require_relative '../helpers/auth_form_helpers'

# Module for routes within auth context
module AuthRoutes
  def self.registered(app)
    app.helpers AuthFormHelpers

    app.get '/login' do
      redirect '/profile' if logged_in?
      erb :login, layout: false
    end

    app.post '/login' do
      email = params[:email]
      password = params[:password]

      return render_login_error('Please fill in email and password.') if credentials_missing?(email, password)

      begin
        user = AuthService.authenticate(email, password)
        if user
          establish_session(user)
        else
          render_login_error('Invalid email or password.')
        end
      rescue StandardError => e
        render_login_error("An error occurred: #{e.message}")
      end
    end

    app.get '/logout' do
      session.clear
      redirect '/login'
    end

    app.get '/register' do
      erb :register, layout: false
    end

    app.post '/register' do
      validation_error = validate_registration_params
      if validation_error
        @error = validation_error
        return erb :register, layout: false
      end

      begin
        user = AuthService.register(params)
        session[:user_id] = user.user_id
        redirect '/profile'
      rescue StandardError => e
        @error = "Registration error: #{e.message}"
        erb :register, layout: false
      end
    end
  end
end
