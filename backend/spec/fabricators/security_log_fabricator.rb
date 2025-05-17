# frozen_string_literal: true

require 'faker'

Fabricator(:security_log) do
  user
  action { SecurityLogDAO::Actions::LOGIN_SUCCESS }
  object { 'User' }
  details { Faker::Lorem.sentence }
  log_timestamp { Time.now }
end
