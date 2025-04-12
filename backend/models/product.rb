class Product < Sequel::Model(DB[:products])
    set_primary_key :product_id
    one_to_many :licenses, key: :product_id
end
