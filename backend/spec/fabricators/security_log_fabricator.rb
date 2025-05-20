# frozen_string_literal: true

require 'faker'
require_relative 'fabricator_helpers'

Fabricator(:security_log) do
  transient :source_user

  # Denormalized user fields
  user_id do |attrs|
    FabricatorHelpers::GET_USER_TO_LOG_FROM.call(attrs, method(:Fabricate)).user_id
  end
  username do |attrs|
    FabricatorHelpers::GET_USER_TO_LOG_FROM.call(attrs, method(:Fabricate)).username
  end
  email do |attrs|
    FabricatorHelpers::GET_USER_TO_LOG_FROM.call(attrs, method(:Fabricate)).email
  end

  log_timestamp { Time.now }
  action do
    if defined?(SecurityLogDAO::Actions)
      SecurityLogDAO::Actions.constants.map { |c| SecurityLogDAO::Actions.const_get(c) }.sample
    else
      %w[LOGIN_SUCCESS PASSWORD_CHANGED USER_CREATED PRODUCT_UPDATED].sample
    end
  end
  object { %w[UserSession UserAccount Product SystemSetting].sample }
  details { Faker::Lorem.sentence }
end
