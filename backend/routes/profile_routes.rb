# frozen_string_literal: true

# Module for routes within profile context
module ProfileRoutes
  def self.registered(app)
    app.get '/profile' do
      require_login
      @title = 'Profile'
      @css   = 'profile'
      @user = current_user # current_user ist das User-Objekt
      erb :'profile/show', layout: :'layouts/application'
    end

    app.post '/update_profile' do
      require_login
      content_type :json # Stellt sicher, dass der Content-Type korrekt gesetzt ist

      field = params[:field]
      value = params[:value]&.strip # strip ist hier gut, um führende/nachfolgende Leerzeichen zu entfernen

      # Die Validierung des 'field' Namens ist bereits im ProfileService,
      # aber eine frühe Validierung hier schadet nicht und kann die Anzahl der Service-Aufrufe reduzieren.
      # ProfileService.ALLOWED_FIELDS ist hier nicht direkt zugänglich,
      # es sei denn, man macht es zu einer öffentlichen Konstante der Klasse.
      # Alternativ: Die Validierung komplett dem Service überlassen.
      # Für dieses Beispiel lassen wir die Validierung im Service, wie es schon war.

      begin
        # current_user ist das User-Objekt des eingeloggten Benutzers
        result_hash = ProfileService.update_profile(current_user, field, value)
        result_hash.to_json
      rescue StandardError => e
        # Dieser Block sollte seltener getroffen werden, da ProfileService
        # bereits viele Fehler abfängt und eine JSON-strukturierte Antwort liefert.
        # Er dient als letzter Ausweg für wirklich unerwartete Fehler im Service oder davor.
        puts "ERROR: Unexpected error in /update_profile route: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        { success: false, message: 'An unexpected server error occurred while updating your profile.' }.to_json
      end
    end
  end
end
