# frozen_string_literal: true

Fabricator(:product) do
  product_name { sequence(:product_name) { |i| "Product #{i}" } }
end
