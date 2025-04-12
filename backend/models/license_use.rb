class LicenseUse < Sequel::Model(DB[:license_uses])
    set_primary_key :use_id
    many_to_one :license_assignment, key: :assignment_id
end
