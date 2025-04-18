class Device < Sequel::Model
    one_to_many :license_assignments, key: :device_id
  
    def validate
      super
      validates_presence :device_name, message: "device name can not be empty"
      validates_unique :serial_number, allow_nil: true, message: "serial number must be unique if specified"
    end
end
