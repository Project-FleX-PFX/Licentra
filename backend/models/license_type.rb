class LicenseType < Sequel::Model(DB[:license_types])
    set_primary_key :license_type_id
    one_to_many :licenses, key: :license_type_id
end
