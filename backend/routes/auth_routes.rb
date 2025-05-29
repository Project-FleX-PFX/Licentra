# frozen_string_literal: true

require_relative '../helpers/auth_form_helpers'
require_relative '../services/auth_service'

# Module for routes within auth context
module AuthRoutes # rubocop:disable Metrics/ModuleLength
  def self.registered(app) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    app.helpers AuthFormHelpers

    app.get '/login' do
      @title = 'Login - Licentra'
      @page_heading = 'Licentra Login'
      @auth_card_footer_partial = :'auth/partials/_login_footer'
      erb :'auth/login', layout: :'layouts/auth'
    end

    app.post '/login' do
      email = params[:email]&.strip
      password = params[:password]
      ip_address = request.ip # IP-Adresse für Logging

      begin
        authenticated_user = AuthService.login(email, password, ip_address: ip_address)
        establish_session(authenticated_user)
        redirect '/' # Erfolgreicher Login
      rescue AuthService::InvalidInputError => e
        render_login_error(e.message)
      rescue AuthService::AccountLockedError => e
        render_login_error(e.message) # Die Nachricht enthält bereits die Lockout-Dauer
      rescue AuthService::AuthenticationError => e
        render_login_error(e.message) # Generische "Invalid email or password." Nachricht
      rescue StandardError => e # Fallback für unerwartete Fehler
        puts "UNEXPECTED LOGIN ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render_login_error('An unexpected server error occurred. Please try again.')
      end
    end

    app.post '/logout' do
      # AuthService.logout(session[:user_id]) # Optional, falls Logout-spezifisches Logging gewünscht
      session.clear
      flash[:success] = 'You have been successfully logged out.'
      redirect '/login'
    end

    app.get '/register' do
      @title = 'Register - Licentra'
      @page_heading = 'Create Account'
      @auth_card_footer_partial = :'auth/partials/_register_footer'
      erb :'auth/register', layout: :'layouts/auth'
    end

    app.post '/register' do
      validation_error = validate_registration_params
      if validation_error
        @error = validation_error
        return erb :'auth/register', layout: :'layouts/auth'
      end

      begin
        user = AuthService.register(params) # params enthält :username, :email, :password etc.
        establish_session(user) # Automatisch einloggen nach Registrierung
        flash[:success] = 'Registration successful! Welcome to Licentra.'
        redirect '/'
      rescue AuthService::RegistrationError => e
        @error = e.message # Die Fehlermeldung vom Service
        erb :'auth/register', layout: :'layouts/auth'
      rescue StandardError => e
        puts "UNEXPECTED REGISTRATION ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        @error = 'An unexpected server error occurred during registration.'
        erb :'auth/register', layout: :'layouts/auth'
      end
    end

    app.get '/forgot_password' do
      @title = 'Forgot Password - Licentra'
      @page_heading = 'Reset Password'
      @auth_card_footer_partial = :'auth/partials/_forgot_password_footer'
      erb :'auth/forgot_password', layout: :'layouts/auth'
    end

    app.post '/forgot_password' do
      email = params[:email]&.strip

      begin
        AuthService.request_password_reset(email)
        # Die AuthService-Methode behandelt bereits das Logging.
        # Die Methode wirft Fehler oder gibt Symbole zurück, aber für den User
        # zeigen wir immer die generische Nachricht, um Enumeration zu verhindern.
      rescue AuthService::InvalidInputError
        # Ignorieren für User-Feedback, bereits serverseitig geloggt falls nötig
      rescue AuthService::PasswordResetError => e
        # Interner Fehler, loggen, aber User bekommt generische Nachricht
        puts "ERROR processing password reset request for #{email}: #{e.message}"
      rescue StandardError => e
        puts "UNEXPECTED ERROR during password reset request for #{email}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      end

      flash[:notice] =
        'If an account with this email address exists and is active, a password reset link has been sent. Please check your inbox and spam folder. Note: A new link can only be requested after 24 hours if the current one expires or does not work.'
      redirect '/login'
    end

    app.get '/reset_password' do
      token = params[:token]&.strip

      if token.nil? || token.empty?
        flash[:error] = 'The password reset link is invalid or the token is missing.'
        return redirect '/login'
      end

      # Validierung, ob der Token überhaupt existiert, bevor das Formular angezeigt wird.
      # AuthService könnte hier eine Methode `validate_reset_token` haben.
      token_data = PasswordResetTokenDAO.find_user_by_token(token)

      if token_data && token_data[:user]
        @token_for_form = token
        @title = 'Set New Password - Licentra'
        @page_heading = 'Set New Password'
        @auth_card_footer_partial = nil
        erb :'auth/reset_password_form', layout: :'layouts/auth'
      else
        flash[:error] = 'Invalid or expired password reset link. Please request a new one.'
        redirect '/login'
      end
    end

    app.post '/reset_password' do
      token = params[:token]&.strip
      new_password = params[:password]
      password_confirmation = params[:password_confirmation]

      @token_for_form = token # Für den Fall, dass das Formular neu gerendert werden muss

      begin
        AuthService.reset_password(token, new_password, password_confirmation)
        flash[:success] = 'Your password has been successfully reset.'
        redirect '/login'
      rescue AuthService::InvalidInputError => e
        flash.now[:error] = e.message
        erb :'auth/reset_password_form', layout: :'layouts/auth' # layout_auth statt :layout_auth
      rescue AuthService::PasswordUpdateError => e
        flash.now[:error] = e.message # Enthält "Invalid or expired..." oder Policy-Fehler
        erb :'auth/reset_password_form', layout: :'layouts/auth'
      rescue StandardError => e
        puts "UNEXPECTED ERROR during password reset submission: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        flash.now[:error] = 'An unexpected server error occurred. Please try again later.'
        erb :'auth/reset_password_form', layout: :'layouts/auth'
      end
    end

    private

    # Hilfsmethode zum Rendern von Login-Fehlern (kann beibehalten oder auch in AuthService integriert werden)
    app.helpers do
      def render_login_error(message)
        @error = message # Für die auth/login.erb Vorlage
        @title = 'Login - Licentra'
        @page_heading = 'Licentra Login'
        @auth_card_footer_partial = :'auth/partials/_login_footer'
        halt erb(:'auth/login', layout: :'layouts/auth') # Stoppt weitere Ausführung und rendert
      end

      def establish_session(user)
        session[:user_id] = user.user_id
        session[:username] = user.username
        # Weitere Session-Daten nach Bedarf
      end

      # Deine bestehende `validate_registration_params` Methode hier oder in AuthFormHelpers
      def validate_registration_params
        # gibt Fehlermeldung (String) oder nil zurück
        return 'Username is required.' if params[:username].nil? || params[:username].strip.empty?
        return 'Email is required.' if params[:email].nil? || params[:email].strip.empty?
        return 'Password is required.' if params[:password].nil? || params[:password].empty?
        if params[:password_confirmation].nil? || params[:password_confirmation].empty?
          return 'Password confirmation is required.'
        end
        return 'Passwords do not match.' if params[:password] != params[:password_confirmation]

        # Weitere Validierungen (Länge, E-Mail-Format etc.)
        nil
      end
    end
  end
end
