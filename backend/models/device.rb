class Device < Sequel::Model
    one_to_many :license_assignments, key: :device_id
  
    def validate
      super
      validates_presence :device_name, message: "Gerätename darf nicht leer sein"
      validates_unique :serial_number, allow_nil: true, message: "Seriennummer muss eindeutig sein, wenn angegeben"
    end
end
