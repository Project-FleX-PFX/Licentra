class LicenseType < Sequel::Model(:license_types)
    one_to_many :licenses, key: :license_type_id
  
    def validate
      super
      validates_presence :type_name
      validates_unique :type_name
    end
end
