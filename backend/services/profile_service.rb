# frozen_string_literal: true

require_relative '../dao/user_dao'
require_relative '../dao/user_credential_dao'
require_relative '../dao/security_log_dao'

# Service class for profiles
class ProfileService
  ALLOWED_FIELDS = %w[username email password].freeze

  # Eigene Fehlerklasse für klarere Fehlerbehandlung in den Routen, falls benötigt
  class ProfileUpdateError < StandardError; end

  class << self
    def update_profile(user_performing_update, field, value) # user umbenannt für Klarheit
      raise ProfileUpdateError, 'Invalid field' unless ALLOWED_FIELDS.include?(field)

      # Der user_performing_update ist hier immer current_user,
      # und er aktualisiert sein eigenes Profil.
      target_user = user_performing_update

      case field
      when 'username'
        update_username(user_performing_update, target_user, value)
      when 'email'
        update_email(user_performing_update, target_user, value)
      when 'password'
        update_password(user_performing_update, target_user, value)
      else
        # Sollte durch die `ALLOWED_FIELDS` Prüfung nicht erreicht werden, aber als Fallback
        { success: false, message: 'Invalid field operation' }
      end
    rescue ProfileUpdateError => e # Fängt spezifische Fehler vom Service ab
      { success: false, message: e.message }
    rescue UserCredential::PasswordPolicyError => e # Fängt Passwort-Policy-Fehler ab
      { success: false, message: "Password update failed: #{e.message}" }
    rescue Sequel::ValidationFailed => e # Fängt allgemeine Validierungsfehler von UserDAO oder UserCredentialDAO ab
      { success: false, message: "Update failed: #{e.errors.full_messages.join(', ')}" }
    rescue StandardError => e # Fängt andere unerwartete Fehler ab
      # Logge den unerwarteten Fehler serverseitig
      puts "ERROR: Unexpected error in ProfileService.update_profile: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, message: 'An unexpected server error occurred.' }
    end

    private

    # user_performing_update: Der User, der die Aktion auslöst (current_user)
    # target_user: Der User, dessen Profil aktualisiert wird (hier identisch)
    # new_username: Der neue Wert
    def update_username(user_performing_update, target_user, new_username)
      old_username = target_user.username # Alten Wert für Log speichern
      raise ProfileUpdateError, 'Username cannot be empty.' if new_username.nil? || new_username.strip.empty?
      raise ProfileUpdateError, 'Username already exists.' if username_taken?(new_username, target_user.user_id)

      updated_user = UserDAO.update(target_user.user_id, username: new_username)
      raise ProfileUpdateError, 'Failed to update username.' unless updated_user

      # Security Log Eintrag
      SecurityLogDAO.log_user_updated(
        acting_user: user_performing_update,
        updated_user: updated_user, # Das aktualisierte User-Objekt
        changes_description: "Username changed from '#{old_username}' to '#{new_username}'."
      )
      { success: true, message: 'Username updated successfully.' }

      # Sollte nicht passieren, wenn UserDAO.update Fehler wirft oder nil bei Fehlschlag zurückgibt
    end

    def update_email(user_performing_update, target_user, new_email)
      old_email = target_user.email # Alten Wert für Log speichern
      raise ProfileUpdateError, 'Email cannot be empty.' if new_email.nil? || new_email.strip.empty?
      # Hier könnte eine E-Mail-Formatvalidierung stehen
      # raise ProfileUpdateError, 'Invalid email format.' unless new_email.match?(URI::MailTo::EMAIL_REGEXP)
      raise ProfileUpdateError, 'Email already exists.' if email_taken?(new_email, target_user.user_id)

      updated_user = UserDAO.update(target_user.user_id, email: new_email)
      raise ProfileUpdateError, 'Failed to update email.' unless updated_user

      # Security Log Eintrag
      SecurityLogDAO.log_user_updated(
        acting_user: user_performing_update,
        updated_user: updated_user,
        changes_description: "Email changed from '#{old_email}' to '#{new_email}'."
      )
      { success: true, message: 'Email updated successfully.' }
    end

    def update_password(user_performing_update, target_user, new_password)
      # UserCredentialDAO.update_password sollte Passwort-Policy-Prüfungen durchführen
      # und ggf. UserCredential::PasswordPolicyError oder Sequel::ValidationFailed werfen.
      raise ProfileUpdateError, 'Password cannot be empty.' if new_password.nil? || new_password.empty?

      updated_credential = UserCredentialDAO.update_password(target_user.user_id, new_password)

      raise ProfileUpdateError, 'Failed to update password for an unknown reason.' unless updated_credential

      # Security Log Eintrag
      SecurityLogDAO.log_password_changed(user_who_changed_password: target_user)
      { success: true, message: 'Password updated successfully.' }

      # Dieser Fall sollte durch Fehler, die von UserCredentialDAO geworfen werden, abgedeckt sein.
    end

    def username_taken?(username, current_user_id)
      existing_user = UserDAO.find_by_username(username)
      existing_user && existing_user.user_id != current_user_id
    end

    def email_taken?(email, current_user_id)
      existing_user = UserDAO.find_by_email(email)
      existing_user && existing_user.user_id != current_user_id
    end
  end
end
