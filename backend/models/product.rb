# frozen_string_literal: true

# Represents a software product that can be licensed
# Contains basic product information like name and description
class Product < Sequel::Model
  one_to_many :licenses, key: :product_id

  def validate
    super
    validates_presence :product_name
    validates_unique :product_name
  end
end
