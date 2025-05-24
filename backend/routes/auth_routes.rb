# frozen_string_literal: true

require_relative '../helpers/auth_form_helpers'

# Module for routes within auth context
module AuthRoutes
  def self.registered(app)
    app.helpers AuthFormHelpers

    app.get '/login' do
      @title = "Login - Licentra"
      @page_heading = "Licentra Login"
      @auth_card_footer_partial = :'auth/partials/_login_footer' # Spezifischer Footer
      erb :'auth/login', layout: :'layouts/auth'
    end

    app.post '/login' do
      email = params[:email]
      password = params[:password]

      return render_login_error('Please fill in email and password.') if credentials_missing?(email, password)

      user = UserDAO.find_by_email(email)

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
      @title = "Register - Licentra"
      @page_heading = "Create Account"
      @auth_card_footer_partial = :'auth/partials/_register_footer' # Spezifischer Footer
      erb :'auth/register', layout: :'layouts/auth'
    end

    app.post '/register' do
      validation_error = validate_registration_params
      if validation_error
        @error = validation_error
        return erb :'auth/register', layout: :'layouts/auth'
      end

      begin
        user_data = {
          username: params[:username],
          email: params[:email],
          first_name: params[:first_name],
          last_name: params[:last_name],
          is_active: true # oder false, je nach gewünschtem Verhalten
        }

        user = UserDAO.create(user_data)

        if params[:password] && !params[:password].empty?
          UserCredentialDAO.create({
                                     user_id: user.user_id,
                                     password: params[:password]
                                   })
        else
          @error = "Password is required."
          return erb :'auth/register', layout: :'layouts/auth'
        end

        session[:user_id] = user.user_id
        redirect '/profile'
      rescue StandardError => e
        @error = "Registration error: #{e.message}"
        erb :'auth/register', layout: :'layouts/auth'
      end
    end

    app.get '/forgot_password' do
      @title = "Forgot Password - Licentra"
      @page_heading = "Reset Password"
      @auth_card_footer_partial = :'auth/partials/_forgot_password_footer' # Spezifischer Footer
      erb :'auth/forgot_password', layout: :'layouts/auth'
    end

    app.post '/forgot_password' do # Korrigiert zu POST
      email = params[:email]&.strip # E-Mail aus dem Formular holen

      # Optionale, aber gute UX: Einfache Validierung der E-Mail-Eingabe
      if email.nil? || email.empty? || !email.match?(URI::MailTo::EMAIL_REGEXP)
        # Für beste Sicherheit (kein Email-Enumerating) trotzdem die generische Nachricht verwenden.
        # Alternativ könnte man hier einen Fehler direkt auf der /forgot_password Seite anzeigen,
        # aber das würde verraten, dass die Eingabe ungültig war, bevor überhaupt geprüft wurde, ob die E-Mail existiert.
        # Wir bleiben bei der generischen Nachricht für alle Fälle.
        puts "DEBUG: Ungültige E-Mail-Format-Eingabe für Passwort-Reset: #{email.inspect}"
      else
        user = UserDAO.find_by_email(email)

        if user && UserDAO.may_reset_password_based_on_user_object?(user)
          klartext_token = PasswordResetTokenDAO.create_token_for_user(user[:user_id])

          if klartext_token
            begin
              # Verwendung von EmailService (wie in vorherigen Antworten)
              MailService.send_password_reset_email(user[:email], klartext_token, user[:user_id])
              UserDAO.record_password_reset_request(user[:user_id])
              puts "DEBUG: Passwort-Reset-Token für #{email} generiert und E-Mail-Versand initiiert."
            rescue MailService::SendError => e # Fehler vom EmailService abfangen
              puts "ERROR: Fehler beim Senden der Passwort-Reset-E-Mail für #{email}: #{e.message}"
              # Fehler loggen, aber der Benutzer sieht trotzdem die generische Nachricht
            rescue => e # Andere unerwartete Fehler
              puts "ERROR: Unerwarteter Fehler beim Passwort-Reset-Prozess für #{email}: #{e.message}"
            end
          else
            puts "ERROR: Konnte keinen Passwort-Reset-Token für #{email} generieren."
          end
        else
          # Benutzer nicht gefunden oder darf kein Reset anfordern (z.B. zu früh, inaktiv)
          puts "DEBUG: Passwort-Reset für #{email} angefordert, aber nicht berechtigt oder Nutzer nicht gefunden."
        end
      end

      # Immer die gleiche generische Nachricht, um kein Feedback über die Existenz
      # oder den Status von E-Mail-Adressen zu geben.
      flash[:notice] = "If an account with this email address exists and is active, a password reset link has been sent. Please check your inbox and spam folder."
      redirect '/login' # Zurück zur Login-Seite, wo die Flash-Nachricht angezeigt wird
    end

    # In Ihrer Sinatra-Anwendung (z.B. innerhalb eines AuthRoutes Moduls)

    app.get '/reset_password' do
      token = params[:token]&.strip # Token aus der URL extrahieren

      if token.nil? || token.empty?
        flash[:error] = "The password reset link is invalid or the token is missing."
        redirect '/login' # Oder '/forgot_password'
        return # Wichtig, um die weitere Ausführung zu stoppen
      end


      token_data = PasswordResetTokenDAO.find_user_by_token(token)

      if token_data && token_data[:user]
        @token_for_form = token
        @title = "Set New Password - Licentra"
        @page_heading = "Set New Password"
        # Für diese Seite vielleicht keinen spezifischen Footer, dann wird der Standard aus layout_auth.erb genommen
        # oder @auth_card_footer_partial = nil explizit setzen, wenn der Standard nicht passt
        @auth_card_footer_partial = nil # Um den Standard-Footer ("Back to Login") zu verwenden oder einen eigenen hier definieren
        erb :'auth/reset_password_form', layout: :'layouts/auth'
      else
        flash[:error] = "Invalid or expired password reset link. Please request a new one."
        redirect '/login' # Oder '/forgot_password'
      end
    end

    app.post '/reset_password' do
      token = params[:token]&.strip
      new_password = params[:password]
      password_confirmation = params[:password_confirmation]

      @token_for_form = token

      if token.nil? || token.empty?
        flash.now[:error] = "Password reset token is missing. Please try the link from your email again."
        return erb :'auth/reset_password_form', layout: :layout_auth
      end

      if new_password.nil? || new_password.empty? || password_confirmation.nil? || password_confirmation.empty?
        flash.now[:error] = "New password and confirmation cannot be empty."
        return erb :'auth/reset_password_form', layout: :layout_auth
      end

      unless new_password == password_confirmation
        flash.now[:error] = "Passwords do not match."
        return erb :'auth/reset_password_form', layout: :layout_auth
      end

      token_data = PasswordResetTokenDAO.find_user_by_token(token)

      unless token_data && token_data[:user]
        flash[:error] = "Invalid or expired password reset link. It may have already been used. Please request a new one."
        redirect '/login'
        return
      end

      user_to_update = token_data[:user]

      begin
        updated_credential = UserCredentialDAO.update_password(user_to_update[:user_id], new_password)

        if updated_credential
          PasswordResetTokenDAO.delete_token(token_data[:token_record_id])

          flash[:success] = "Your password has been successfully reset."
          redirect '/login'
        else
          flash.now[:error] = "An unknown error occurred while updating your password. Please try again."
          erb :'auth/reset_password_form', layout: :layout_auth
        end

      rescue UserCredential::PasswordPolicyError => e
        flash.now[:error] = "Password could not be updated: #{e.message}"
        erb :'auth/reset_password_form', layout: :layout_auth
      rescue Sequel::ValidationFailed => e
        error_messages = e.errors.full_messages.join(', ')
        flash.now[:error] = "Password update failed due to validation errors: #{error_messages}"
        erb :'auth/reset_password_form', layout: :layout_auth
      rescue => e
        puts "UNEXPECTED ERROR during password reset for user_id #{user_to_update[:user_id]}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        flash.now[:error] = "An unexpected server error occurred. Please try again later."
        erb :'auth/reset_password_form', layout: :layout_auth
      end
    end
  end
end
