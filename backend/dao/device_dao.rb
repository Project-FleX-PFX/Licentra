require_relative '../models/device'
require_relative 'errors'

class DeviceDAO

    def self.find(id)
      Device[id]
    end
  
    def self.find_by(criteria)
      Device.first(criteria)
    rescue Sequel::Error => e
      raise DatabaseError, "Fehler beim Suchen eines Geräts nach Kriterien: #{e.message}"
    end
  
    def self.all(options = {})
      dataset = Device.dataset
      dataset = dataset.where(options[:where]) if options[:where]
      dataset = dataset.order(options[:order]) if options[:order]
      dataset.all
    rescue Sequel::Error => e
      raise DatabaseError, "Fehler beim Abrufen aller Geräte: #{e.message}"
    end
  
    def self.where(criteria)
       Device.where(criteria)
    rescue Sequel::Error => e
      raise DatabaseError, "Fehler beim Filtern von Geräten: #{e.message}"
    end
  
    def self.create(attributes)
      device = Device.new(attributes)
      if device.valid?
        device.save
        device
      else
        raise ValidationError.new("Validierung beim Erstellen fehlgeschlagen", device.errors, device)
      end
    rescue Sequel::ValidationFailed => e
       raise ValidationError.new(e.message, e.errors, e.model)
    rescue Sequel::DatabaseError => e
       raise DatabaseError, "Datenbankfehler beim Erstellen des Geräts: #{e.message}"
    end
  
    def self.update(id, attributes)
      device = Device[id]
      raise RecordNotFound, "Gerät mit ID #{id} nicht gefunden" unless device
  
      begin
        device.update(attributes)
        device
      rescue Sequel::ValidationFailed => e
        raise ValidationError.new("Validierung beim Aktualisieren fehlgeschlagen", e.errors, e.model)
      rescue Sequel::DatabaseError => e
        raise DatabaseError, "Datenbankfehler beim Aktualisieren des Geräts #{id}: #{e.message}"
      end
    end
  
    def self.delete(id)
      device = Device[id]
      raise RecordNotFound, "Gerät mit ID #{id} zum Löschen nicht gefunden" unless device
  
      begin
        device.destroy
        true
      rescue Sequel::DatabaseError => e
        raise DatabaseError, "Datenbankfehler beim Löschen des Geräts #{id}: #{e.message}"
      end
    end
  
    def self.find_by_serial_number(serial_number)
      return nil if serial_number.nil?
      find_by(serial_number: serial_number)
    end
  
    def self.find_with_licenses
       Device.eager(:license_assignments).exclude(license_assignments: nil).all
    rescue Sequel::Error => e
       raise DatabaseError, "Fehler beim Suchen von Geräten mit Lizenzen: #{e.message}"
    end
  
end
