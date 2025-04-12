class License < Sequel::Model
    many_to_one :product, key: :product_id
    many_to_one :license_type, key: :license_type_id
    one_to_many :license_assignments, key: :license_id
  
    def available_seats
      assigned_count = self.license_assignments_dataset.where(is_active: true).count
      [0, self.seat_count - assigned_count].max
    end
  
    def validate
      super
      validates_presence [:product_id, :license_type_id, :seat_count]
      validates_integer :seat_count
      validates_operator(:>=, 1, :seat_count, message: 'must be at least 1')
    end
end
