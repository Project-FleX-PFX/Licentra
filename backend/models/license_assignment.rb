class LicenseAssignment < Sequel::Model(DB[:license_assignments])
    set_primary_key :assignment_id
    many_to_one :user, key: :user_id
    many_to_one :license, key: :license_id
    one_to_many :license_uses, key: :assignment_id
end
