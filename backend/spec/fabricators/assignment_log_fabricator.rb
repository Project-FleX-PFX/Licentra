# frozen_string_literal: true

require 'faker'
require_relative 'fabricator_helpers'

Fabricator(:assignment_log) do
  transient :source_user, :source_license, :license_assignment

  user_id do |attrs|
    FabricatorHelpers::GET_USER_TO_LOG_FROM.call(attrs, method(:Fabricate)).pk
  end
  username do |attrs|
    FabricatorHelpers::GET_USER_TO_LOG_FROM.call(attrs, method(:Fabricate)).username
  end
  email do |attrs|
    FabricatorHelpers::GET_USER_TO_LOG_FROM.call(attrs, method(:Fabricate)).email
  end

  license_id do |attrs|
    FabricatorHelpers::GET_LICENSE_TO_LOG_FROM.call(attrs, method(:Fabricate)).pk
  end
  license_name do |attrs|
    FabricatorHelpers::GET_LICENSE_TO_LOG_FROM.call(attrs, method(:Fabricate)).license_name
  end

  log_timestamp { Time.now }
  action { FabricatorHelpers::GET_SAMPLE_ACTION.call }
  object { FabricatorHelpers::GET_SAMPLE_OBJECT_STRING.call }
  details { Faker::Lorem.sentence(word_count: rand(5..10)) }
end
