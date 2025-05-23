require 'mail'

module MailService
  class ConfigurationError < StandardError; end
  class SendError < StandardError; end

  def self.configure_mailer!
    smtp_settings = AppConfigDAO.get_smtp_settings

    unless smtp_settings && smtp_settings[:server] && smtp_settings[:port] && smtp_settings[:username] && smtp_settings[:password]
      raise ConfigurationError, "SMTP settings are not fully configured. Please check admin settings."
    end

    required_keys = [:server, :port, :username, :password]
    missing_keys = []
    invalid_values = {}

    required_keys.each do |key|
      value = smtp_settings[key]
      if value.nil? || (value.is_a?(String) && value.empty?)
        missing_keys << key
      end
    end

    unless missing_keys.empty?
      raise ConfigurationError, "SMTP settings are incomplete. Missing or empty: #{missing_keys.join(', ')}. Please check admin settings."
    end

    # Spezifische Port-Validierung
    port = smtp_settings[:port]
    unless port.is_a?(Integer) && port > 0 && port <= 65535
      # Versuche, den Port zu einem Integer zu konvertieren, falls er als String vorliegt
      begin
        port_as_int = Integer(port)
        if port_as_int > 0 && port_as_int <= 65535
          smtp_settings[:port] = port_as_int # Korrigierten Wert verwenden
        else
          invalid_values[:port] = "must be a valid port number (1-65535), got '#{port}'"
        end
      rescue ArgumentError, TypeError
        invalid_values[:port] = "must be a valid integer port number, got '#{port.class}: #{port}'"
      end
    end

    # Weitere Validierungen (optional, aber gut):
    # Server-Adresse könnte auf ein einfaches Format geprüft werden (nicht leer, keine offensichtlich falschen Zeichen)
    unless smtp_settings[:server].is_a?(String) && !smtp_settings[:server].strip.empty?
      invalid_values[:server] = "must be a non-empty string, got '#{smtp_settings[:server].class}'"
    end
    # Username (E-Mail) könnte auf ein E-Mail-Format geprüft werden
    unless smtp_settings[:username].is_a?(String) && smtp_settings[:username].match?(URI::MailTo::EMAIL_REGEXP)
      invalid_values[:username] = "must be a valid email address, got '#{smtp_settings[:username]}'"
    end
    # Security-Typ könnte auf gültige Werte geprüft werden
    valid_security_types = ['SSL', 'TLS', 'NONE', nil, ''] # nil oder leer für Auto-Detection oder Default
    unless valid_security_types.include?(smtp_settings[:security]&.upcase)
      invalid_values[:security] = "must be one of #{valid_security_types.compact.join(', ')}, got '#{smtp_settings[:security]}'"
    end


    unless invalid_values.empty?
      error_details = invalid_values.map { |k, v| "#{k} #{v}" }.join('; ')
      raise ConfigurationError, "Invalid SMTP settings: #{error_details}. Please check admin settings."
    end

    # --- ENDE VALIDIERUNG ---

    delivery_options = {
      address:        smtp_settings[:server],
      port:           smtp_settings[:port].to_i,
      domain:         smtp_settings[:username].split('@').last,
      user_name:      smtp_settings[:username],
      password:       smtp_settings[:password],
      authentication: 'plain'
    }

    case smtp_settings[:security]&.upcase
    when 'SSL'

      delivery_options[:ssl] = true
      delivery_options[:enable_starttls_auto] = false
    when 'TLS'
      delivery_options[:enable_starttls_auto] = true
    when 'NONE'
      delivery_options[:enable_starttls_auto] = false
    else
      if smtp_settings[:port].to_i == 587
        delivery_options[:enable_starttls_auto] = true
      elsif smtp_settings[:port].to_i == 465
        delivery_options[:ssl] = true
        delivery_options[:enable_starttls_auto] = false
      end
    end

    puts "DEBUG: Mail delivery_options: #{delivery_options.inspect}" # Für Debugging

    Mail.defaults do
      delivery_method :smtp, delivery_options
    end
  rescue AppConfigDAO::ConfigLoadError => e # Fängt den Fehler vom DAO
    # Dieser Fehler beinhaltet bereits, dass die Konfiguration (wahrscheinlich wegen Entschlüsselung) fehlgeschlagen ist.
    # Wir wandeln ihn in einen EmailService-spezifischen Konfigurationsfehler um.
    raise ConfigurationError, "Failed to configure mailer due to an issue with SMTP settings: #{e.message}"
  rescue => e # Andere unerwartete Fehler während der Konfiguration selbst
    raise ConfigurationError, "Unexpected error during mailer configuration: #{e.message}"
  end

  def self.send_test_email(recipient_email)
    configure_mailer!

    from_address = AppConfigDAO.get_smtp_settings[:username]

    mail_content = Mail.new do
      from     from_address
      to       recipient_email
      subject  'Licentra - SMTP Test Email'
      body     "This is a test email sent from your Licentra application using the configured SMTP settings.\n\nTime: #{Time.now}"

    end

    puts "DEBUG: Attempting to send test email to #{recipient_email} from #{from_address}"
    mail_content.deliver!
    puts "DEBUG: Test email to #{recipient_email} sent successfully."
    true
  rescue ConfigurationError => e
    # Dieser Fehler kommt von configure_mailer! oder direkt von hier, falls get_smtp_settings fehlschlägt
    puts "ERROR (Configuration) in send_test_email: #{e.message}"
    raise SendError, "Cannot send email: Mailer configuration failed. #{e.message}" # Bessere Nachricht
  rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPFatalError, Net::SMTPSyntaxError, Timeout::Error => e
    error_message = "SMTP Error while sending test email to #{recipient_email}: #{e.class} - #{e.message}"
    puts "ERROR (SMTP) in send_test_email: #{error_message}"
    raise SendError, error_message
  rescue => e # Alle anderen Fehler (z.B. SocketError, etc.)
    error_message = "Generic error while sending test email to #{recipient_email}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    puts "ERROR (Generic) in send_test_email: #{error_message}"
    raise SendError, error_message
  end

  def self.send_password_reset_email(recipient_email, klartext_token, user_id)
    configure_mailer! # Stellt sicher, dass Mailer konfiguriert ist

    from_address = AppConfigDAO.get_smtp_settings[:username]

    # 1. RACK_ENV sicher abrufen, standardmäßig auf 'development' setzen, falls nicht vorhanden
    rack_env = ENV.fetch('RACK_ENV', 'development')

    # 2. base_url basierend auf rack_env bestimmen
    base_url = if rack_env == 'production'
                 # In Produktion MUSS APP_BASE_URL gesetzt sein.
                 # ENV.fetch ohne zweiten Parameter löst einen Fehler aus, wenn der Key nicht existiert.
                 ENV.fetch('APP_BASE_URL')
               else
                 # Für andere Umgebungen (development, test, etc.)
                 # Erlaube ein Überschreiben durch APP_BASE_URL, aber setze einen lokalen Standardwert.
                 ENV.fetch('APP_BASE_URL', 'http://localhost:4567')
               end
    reset_link = "#{base_url}/reset_password?token=#{CGI.escape(klartext_token)}"

    mail_content = Mail.new do
      from     from_address
      to       recipient_email
      subject  'Licentra - Password Reset Request'
      body     "Hello,\n\nPlease click the following link to reset your password:\n#{reset_link}\n\nThis link will expire in #{PasswordResetTokenDAO::TOKEN_VALIDITY_HOURS} hour(s).\n\nIf you did not request this, please ignore this email."
    end

    puts "DEBUG: Attempting to send password reset email to #{recipient_email}"
    mail_content.deliver!
    puts "DEBUG: Password reset email to #{recipient_email} sent successfully."
    true
  rescue ConfigurationError => e
    puts "ERROR (Configuration) sending reset mail: #{e.message}"
    raise SendError, e.message
  rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPFatalError, Net::SMTPSyntaxError, Timeout::Error => e
    error_message = "SMTP Error while sending reset email to #{recipient_email}: #{e.class} - #{e.message}"
    puts "ERROR (SMTP) sending reset mail: #{error_message}"
    raise SendError, error_message
  rescue => e
    error_message = "Generic error while sending reset email to #{recipient_email}: #{e.class} - #{e.message}"
    puts "ERROR (Generic) sending reset mail: #{error_message}"
    raise SendError, error_message
  end
end