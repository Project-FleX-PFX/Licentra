# frozen_string_literal: true

require_relative '../models/user'
require_relative '../dao/user_dao'
require_relative '../dao/role_dao'
require_relative '../dao/security_log_dao'
require_relative '../dao/password_reset_token_dao'
require_relative '../dao/user_credential_dao'
require_relative 'mail_service'

# Service class which handles auth and related logging
class AuthService
  # Eigene Fehlerklassen für klarere Fehlerbehandlung in den Routen
  class AuthenticationError < StandardError; end
  class RegistrationError < StandardError; end
  class AccountLockedError < AuthenticationError; end
  class PasswordResetError < StandardError; end
  class PasswordUpdateError < StandardError; end
  class InvalidInputError < StandardError; end

  # --- LOGIN ---
  def self.login(email, password, ip_address: nil)
    raise InvalidInputError, 'Email and password are required.' if credentials_missing?(email, password)

    user = UserDAO.find_by_email(email)

    unless user&.is_active
      SecurityLogDAO.log_login_failure(attempted_username: email, ip_address: ip_address)
      raise AuthenticationError, 'Invalid email or password.'
    end

    if UserDAO.locked?(user)
      SecurityLogDAO.log_login_failure(attempted_username: email, ip_address: ip_address) # Erneut loggen, falls versucht wird, sich einzuloggen
      raise AccountLockedError,
            "Your account has been blocked due to too many failed login attempts. Please try again in #{UserDAO::LOCKOUT_DURATION / 60} minutes."
    end

    if user.authenticate(password) # Direkter Aufruf der authenticate Methode des User-Modells
      UserDAO.reset_lockout(user)
      SecurityLogDAO.log_login_success(user: user)
      user
    else
      updated_user = UserDAO.increment_failed_attempts(user)
      SecurityLogDAO.log_login_failure(attempted_username: email, ip_address: ip_address)

      unless updated_user&.failed_login_attempts && updated_user.failed_login_attempts >= UserDAO::MAX_LOGIN_ATTEMPTS
        raise AuthenticationError, 'Invalid email or password.'
      end

      UserDAO.lock_user(updated_user)
      raise AccountLockedError,
            "Incorrect password. Your account has been blocked due to too many failed attempts. Please try again in #{UserDAO::LOCKOUT_DURATION / 60} minutes."

    end
  end

  # --- LOGOUT ---
  # Logout ist primär Session-Management, Logging ist hier optional,
  # es sei denn, man möchte jeden Logout explizit als Security-Event loggen.
  # Für dieses Beispiel lassen wir es ohne spezifischen Logout-Log, da die Session einfach gelöscht wird.

  # --- REGISTRATION ---
  def self.register(params)
    # Validierung könnte hier auch stattfinden oder von der Route übernommen werden
    # Für dieses Beispiel nehmen wir an, die Route hat Basis-Validierungen gemacht.
    # Die User-Erstellung und Rollenzuweisung bleibt ähnlich.

    is_first_user = UserDAO.all.empty? # Prüfen, ob es der erste User ist

    user = User.new( # Erstellt das User-Objekt
      username: params[:username],
      email: params[:email],
      first_name: params[:first_name],
      last_name: params[:last_name],
      is_active: true, # Neue User sind standardmäßig aktiv
      credential_attributes: { password: params[:password] }
      # Das Passwort wird durch UserCredentialDAO beim Speichern gehasht
    )
    # Transaktion für atomare Operation
    DB.transaction do
      user.save_changes # Speichert den User
      raise RegistrationError, "User validation failed: #{user.errors.full_messages.join(', ')}" unless user.valid?

      assign_roles(user, is_first_user) # Weist Rollen zu
    end

    # Wichtig: Der 'acting_user' für log_user_created ist hier der 'created_user' selbst
    # oder ein System-User, falls die Registrierung nicht von einem Admin ausgelöst wird.
    # Da dies eine Selbstregistrierung ist, ist der User selbst der Handelnde.
    SecurityLogDAO.log_user_created(acting_user: user, created_user: user)
    user
  rescue Sequel::ValidationFailed => e
    # Fehler von User oder UserCredential Validierung abfangen
    raise RegistrationError, "Registration failed: #{e.errors.full_messages.join(', ')}"
  rescue StandardError => e
    # Andere unerwartete Fehler
    raise RegistrationError, "An unexpected error occurred during registration: #{e.message}"
  end

  # --- PASSWORD RESET REQUEST ---
  def self.request_password_reset(email)
    raise InvalidInputError, 'Email address is required.' if email.nil? || email.empty?

    # Einfache Formatprüfung optional hier, aber für Security besser generische Nachrichten
    # unless email.match?(URI::MailTo::EMAIL_REGEXP)
    #   # Loggen, aber generische Antwort
    #   # SecurityLogDAO.log_password_reset_request(user_making_request: SecurityLogDAO._unknown_user_for_logging, target_email: email) # Beispiel
    #   return :invalid_email_format # oder raise
    # end

    user = UserDAO.find_by_email(email)

    # acting_user für den Log ist der System-User oder der User selbst, wenn er angemeldet wäre (was hier nicht der Fall ist)
    # Daher verwenden wir _unknown_user_for_logging oder _system_user_for_logging
    acting_user_for_log = user || SecurityLogDAO._unknown_user_for_logging

    if user && UserDAO.may_reset_password_based_on_user_object?(user)
      klartext_token = PasswordResetTokenDAO.create_token_for_user(user.user_id)

      raise PasswordResetError, 'Could not generate password reset token.' unless klartext_token

      MailService.send_password_reset_email(user.email, klartext_token, user.user_id)
      UserDAO.record_password_reset_request(user.user_id) # Aktualisiert last_password_reset_request_at
      # Der "handelnde User" ist hier der User, der das Passwort zurücksetzt (also `user`)
      # oder ein System-User, da der Request oft ohne aktive Session erfolgt.
      SecurityLogDAO.log_password_reset_request(user_making_request: acting_user_for_log, target_email: email)
      :success # Signalisiert Erfolg

    # Token-Erstellung fehlgeschlagen (interner Fehler)
    # Loggen des Fehlers im PasswordResetTokenDAO wäre gut

    else
      # User nicht gefunden oder darf kein Reset anfordern.
      # Loggen als Versuch, aber mit generischer Nachricht an den Client.
      # Wenn User nicht existiert, ist acting_user_for_log der _unknown_user_for_logging.
      SecurityLogDAO.log_password_reset_request(user_making_request: acting_user_for_log, target_email: email)
      :user_not_found_or_not_eligible # Signalisiert diesen Fall
    end
  rescue MailService::SendError => e
    # E-Mail-Versand fehlgeschlagen, aber der Prozess an sich war "erfolgreich" bis dahin
    # Loggen des Fehlers, aber für den User sieht es aus wie Erfolg.
    # SecurityLogDAO.log_password_reset_request(...) wurde oben schon geloggt.
    puts "ERROR: MailService failed to send password reset email for #{email}: #{e.message}"
    # Kein Fehler an den Client weitergeben, um Enumeration zu vermeiden
    :email_send_failed_silently
  rescue StandardError => e
    # Andere unerwartete Fehler
    puts "ERROR: Unexpected error during password reset request for #{email}: #{e.message}"
    raise PasswordResetError, "An unexpected error occurred: #{e.message}"
  end

  # --- RESET PASSWORD (Formular absenden) ---
  def self.reset_password(token, new_password, password_confirmation)
    raise InvalidInputError, 'Token is missing.' if token.nil? || token.empty?

    if new_password.nil? || new_password.empty? || password_confirmation.nil? || password_confirmation.empty?
      raise InvalidInputError,
            'New password and confirmation cannot be empty.'
    end
    raise InvalidInputError, 'Passwords do not match.' unless new_password == password_confirmation

    token_data = PasswordResetTokenDAO.find_user_by_token(token)

    unless token_data && token_data[:user]
      # Hier könnte man auch einen Logeintrag für einen ungültigen Token-Versuch machen
      # SecurityLogDAO.log_generic_event(action: 'invalid password reset attempt', details: "Invalid token: #{token}")
      raise PasswordUpdateError, 'Invalid or expired password reset link.'
    end

    user_to_update = token_data[:user] # Ist ein User-Objekt

    begin
      # Das UserCredentialDAO.update_password sollte intern die Passwort-Policy-Prüfungen machen.
      updated_credential = UserCredentialDAO.update_password(user_to_update.user_id, new_password)

      raise PasswordUpdateError, 'Password update failed for an unknown reason.' unless updated_credential

      PasswordResetTokenDAO.delete_token(token_data[:token_record_id])
      SecurityLogDAO.log_password_changed(user_who_changed_password: user_to_update)
      :success

    # Sollte durch Fehler in UserCredentialDAO abgedeckt sein
    rescue UserCredential::PasswordPolicyError => e # Annahme, dass UserCredentialDAO diesen Fehler wirft
      raise PasswordUpdateError, "Password could not be updated: #{e.message}" # Weitergabe der Policy-Fehlermeldung
    rescue Sequel::ValidationFailed => e
      raise PasswordUpdateError, "Password update failed: #{e.errors.full_messages.join(', ')}"
    rescue StandardError => e
      puts "UNEXPECTED ERROR during password reset for user_id #{user_to_update.user_id}: #{e.class} - #{e.message}"
      raise PasswordUpdateError, 'An unexpected server error occurred.'
    end
  end

  private_class_method

  # Hilfsmethode, die aus der Route hierher verschoben wurde
  def self.credentials_missing?(email, password)
    email.nil? || email.strip.empty? || password.nil? || password.empty?
  end

  # Hilfsmethode, die aus der Route hierher verschoben wurde
  def self.assign_roles(user, is_first_user)
    # Rollen werden dem User-Objekt hinzugefügt
    if is_first_user
      admin_role = RoleDAO.find_by_name('Admin')
      user.add_role(admin_role) if admin_role # add_role ist eine Methode des User-Modells
    end

    user_role = RoleDAO.find_by_name('User')
    user.add_role(user_role) if user_role
    # Das User-Objekt muss danach nicht erneut gespeichert werden, wenn add_role die Änderungen direkt in der DB vornimmt
    # oder das User-Objekt für ein späteres Speichern markiert.
    # Sequel's many_to_many add_ Methode speichert die Assoziation normalerweise direkt.
  end
end
