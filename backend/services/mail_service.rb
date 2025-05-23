require 'mail'

module MailService
  class ConfigurationError < StandardError; end
  class SendError < StandardError; end

  def self.configure_mailer!
    smtp_settings = AppConfigDAO.get_smtp_settings

    unless smtp_settings && smtp_settings[:server] && smtp_settings[:port] && smtp_settings[:username] && smtp_settings[:password]
      raise ConfigurationError, "SMTP settings are not fully configured. Please check admin settings."
    end

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
  rescue AppConfigDAO::DecryptionError => e
    raise ConfigurationError, "Failed to decrypt SMTP settings: #{e.message}"
  rescue => e
    raise ConfigurationError, "Error loading/configuring SMTP settings: #{e.message}"
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
    puts "ERROR (Configuration): #{e.message}"
    raise SendError, e.message
  rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPFatalError, Net::SMTPSyntaxError, Timeout::Error => e
    error_message = "SMTP Error while sending test email to #{recipient_email}: #{e.class} - #{e.message}"
    puts "ERROR (SMTP): #{error_message}"
    raise SendError, error_message
  rescue => e
    error_message = "Generic error while sending test email to #{recipient_email}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    puts "ERROR (Generic): #{error_message}"
    raise SendError, error_message
  end

  # Zukünftige Methode für Passwort-Reset-E-Mails
  def self.send_password_reset_email(recipient_email, reset_token, user_id)
    # configure_mailer!
    # from_address = AppConfigDAO.get_smtp_settings[:username]
    # reset_link = "https://ihre-licentra-domain.com/reset_password?token=#{reset_token}&user_id=#{user_id}"
    #
    # Mail.deliver do
    #   to      recipient_email
    #   from    from_address
    #   subject 'Licentra - Password Reset Request'
    #   body    "Hello,\n\nPlease click the following link to reset your password:\n#{reset_link}\n\nIf you did not request this, please ignore this email."
    # end
    # true
  rescue => e
    # Fehlerbehandlung
    # raise SendError, "Failed to send password reset email: #{e.message}"
  end
end