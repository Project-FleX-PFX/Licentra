# frozen_string_literal: true

# Represents a software license that can be assigned to users or devices
# Contains license details such as key, validity period, cost, and status
class License < Sequel::Model
  many_to_one :product, key: :product_id
  many_to_one :license_type, key: :license_type_id
  one_to_many :license_assignments, key: :license_id

  def available_seats
    assigned_count = license_assignments_dataset.where(is_active: true).count
    [0, seat_count - assigned_count].max
  end

  def status
    return 'Active' if expire_date.nil? || expire_date >= Date.today

    'Expired'
  end

  def to_api_hash
    {
      license_id: license_id,
      license_name: license_name,
      license_key: license_key,
      product_id: product_id,
      product_name: product&.product_name,
      available_seats: available_seats,
      seat_count: seat_count
    }
  end

  def validate
    super
    validates_presence %i[product_id license_type_id seat_count]
    validates_integer :seat_count
    validates_operator(:>=, 1, :seat_count, message: 'must be at least 1')
  end
end
