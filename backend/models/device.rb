class Device < Sequel::Model
    one_to_many :license_assignments, key: :device_id
  
    def validate
      super
      validates_presence :device_name
      validates_unique :serial_number, allow_nil: true
    end
end
