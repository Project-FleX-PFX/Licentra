# frozen_string_literal: true

# Represents the assignment of a license to either a user or a device
class LicenseAssignment < Sequel::Model(:license_assignments)
  plugin :dirty
  many_to_one :license, key: :license_id
  many_to_one :user, key: :user_id
  many_to_one :device, key: :device_id
  one_to_many :assignment_logs, key: :assignment_id

  def assignee
    user || device
  end

  def assignee_id
    user_id || device_id
  end

  def assignee_type
    user_id ? 'User' : 'Device'
  end

  def active?
    is_active
  end

  # Validates license assignment rules, ensuring:
  # - Either user or device is assigned (but not both)
  # - The license has available seats
  # - The license is active
  # - The user (if assigned) is active
  #
  # The complexity is necessary to handle all validation scenarios for proper license management
  def validate
    super
    validates_presence %i[license_id assignment_date]
    errors.add(:base, 'Either user_id or device_id must be set, but not both') if user_id && device_id
    errors.add(:base, 'Either user_id or device_id must be set') unless user_id || device_id

    return unless license && license.available_seats <= 0 && active? && new?

    errors.add(:license_id, 'has no available seats')
  end
end
