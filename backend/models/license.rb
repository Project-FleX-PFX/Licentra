class License < Sequel::Model(DB[:licenses])
    set_primary_key :license_id
    many_to_one :product, key: :product_id
    many_to_one :license_type, key: :license_type_id
    one_to_many :license_assignments, key: :license_id
end
