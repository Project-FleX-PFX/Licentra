# frozen_string_literal: true

require 'faker'

module FabricatorHelpers
  # Helper proc to determine the user object whose data will be denormalized.
  GET_USER_TO_LOG_FROM = proc do |attrs, fabricate_method|
    attrs[:source_user] || fabricate_method.call(:user, username: Faker::Internet.unique.username(specifier: 5..12),
                                                        email: Faker::Internet.unique.email)
  end

  # Helper proc to determine the license object whose data will be denormalized.
  GET_LICENSE_TO_LOG_FROM = proc do |attrs, fabricate_method|
    attrs[:source_license] || attrs[:license_assignment]&.license || fabricate_method.call(:license)
  end

  # Helper proc to get a sample action
  GET_SAMPLE_ACTION = proc do
    if defined?(AssignmentLogDAO::Actions)
      AssignmentLogDAO::Actions.constants.map { |c| AssignmentLogDAO::Actions.const_get(c) }.sample
    else
      %w[USER_ACTIVATED ADMIN_APPROVED LICENSE_IMPORTED SYSTEM_TASK_COMPLETED USER_DEACTIVATED ADMIN_CANCELED].sample
    end
  end

  # Helper proc to get a sample object string
  GET_SAMPLE_OBJECT_STRING = proc do
    %w[LicenseAssignment UserAccount License SystemProcess Product].sample
  end
end
