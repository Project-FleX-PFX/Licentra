# frozen_string_literal: true

require_relative '../config/environment'

puts 'Seeding minimal production database...'

DB.transaction(rollback: :reraise) do
  # Only create roles if they do not yet exist
  unless Role.where(role_name: 'Admin').first
    puts 'Creating Roles...'
    Role.create(role_name: 'Admin')
    Role.create(role_name: 'LicenseManager')
    Role.create(role_name: 'User')
  end

  # Further basic settings could be made here
  # e.g. standard license types, if they do not yet exist
  unless LicenseType.where(type_name: 'Perpetual User').first
    puts 'Creating License Types...'
    LicenseType.create(type_name: 'Perpetual User', description: 'Einmaliger Kauf pro Benutzer.')
    LicenseType.create(type_name: 'Subscription User', description: 'Abonnement pro Benutzer.')
    LicenseType.create(type_name: 'Volume Subscription User',
                       description: 'Abonnement für mehrere Benutzer (pro Platz).')
    LicenseType.create(type_name: 'Device License', description: 'Lizenz ist an ein Gerät gebunden.')
    LicenseType.create(type_name: 'Concurrent Usage', description: 'Maximale Anzahl gleichzeitiger Nutzer.')
  end

  puts 'Production seeding finished successfully.'
end
