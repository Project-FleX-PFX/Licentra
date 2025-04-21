# frozen_string_literal: true

# Represents a type of license (e.g., Perpetual, Subscription, Device-based)
# Defines the characteristics and limitations of licenses
class LicenseType < Sequel::Model(:license_types)
  one_to_many :licenses, key: :license_type_id

  def validate
    super
    validates_presence :type_name
    validates_unique :type_name
  end
end
