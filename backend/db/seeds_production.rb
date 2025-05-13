# frozen_string_literal: true

require_relative '../config/environment'

puts 'Seeding minimal production database...'

DB.transaction(rollback: :reraise) do
  # Only create roles if they do not yet exist
  unless Role.where(role_name: 'Admin').first
    puts 'Creating Roles...'
    Role.create(role_name: 'Admin')
    Role.create(role_name: 'User')
  end

  # Further basic settings could be made here
  # e.g. standard license types, if they do not yet exist
  unless LicenseType.where(type_name: 'User License').first
    puts 'Creating License Types...'
    LicenseType.create(type_name: 'User License', description: 'License set up for one user.')
    LicenseType.create(type_name: 'Volume License', description: 'License set up for multiple users.')
  end

  puts 'Production seeding finished successfully.'
end
