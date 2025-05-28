# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Product Management API' do
  let!(:admin_user) { create_admin_user }
  let!(:regular_user) { create_regular_user }

  def create_product_via_api(name)
    post '/admin/products', { product: { product_name: name } }
  end

  def update_product_via_api(id, name)
    patch "/admin/products/#{id}", { product: { product_name: name } }
  end

  before(:each) do
    Product.dataset.delete
    login_as(admin_user)
  end

  describe 'GET /admin/products' do
    it 'displays the product management page' do
      get '/admin/products'
      expect(response_status).to be(200)
      expect(response_body).to include('Product Management')
    end

    it 'denies access for unauthenticated users' do
      logout
      get '/admin/products'
      expect(response_status).to be(302)
      expect(last_response.location).to include('/login')
    end

    it 'displays all existing products' do
      product1 = create_product_via_dao(name: 'Test Product Alpha')
      product2 = create_product_via_dao(name: 'Test Product Beta')

      get '/admin/products'
      expect(response_status).to eq(200)
      expect(response_body).to include(product1.product_name)
      expect(response_body).to include(product2.product_name)
    end
  end

  describe 'POST /admin/products' do
    it 'creates a new product' do
      create_product_via_api('New Shiny Product')
      expect(response_status).to eq(200)
      product = Product.first(product_name: 'New Shiny Product')
      expect(product).not_to be_nil
    end

    it 'prevents creating products with duplicate names' do
      create_product_via_api('Unique Product Name')
      expect(response_status).to eq(200)

      create_product_via_api('Unique Product Name')
      expect(response_status).to eq(422)
    end
  end

  describe 'PUT /admin/products/:id' do
    let!(:product) { create_product_via_dao(name: 'Original Product Name') }

    it 'updates an existing product' do
      update_product_via_api(product.product_id, 'Updated Product Name')
      expect(response_status).to eq(200)
      updated_product = Product.first(product_id: product.product_id)
      expect(updated_product.product_name).to eq('Updated Product Name')
    end

    it 'prevents updating to an already used name' do
      create_product_via_dao(name: 'Another Name')
      update_product_via_api(product.product_id, 'Another Name')
      expect(response_status).to eq(422)
    end

    it 'returns an error if the product does not exist' do
      update_product_via_api(9999, 'Nonexistent Product')
      expect(response_status).to eq(404)
    end
  end

  describe 'Access control for non-admin users' do
    before(:each) do
      logout
      login_as(regular_user)
    end

    it 'denies regular users access to GET /admin/products' do
      get '/admin/products'
      expect(response_status).to eq(403)
    end

    it 'denies regular users to POST /admin/products' do
      create_product_via_api('User Attempt Product')
      expect(response_status).to eq(403)
    end

    it 'denies regular users to PUT /admin/products/:id' do
      login_as(admin_user)

      product_name_by_admin = "Product By Admin #{SecureRandom.hex(4)}"
      create_product_via_api(product_name_by_admin)

      unless response_status == 200
        raise "Admin konnte Produkt '#{product_name_by_admin}' nicht erstellen. Status: #{response_status}, Body: #{response_body}"
      end

      created_product = Product.first(product_name: product_name_by_admin)
      expect(created_product).not_to be_nil,
                                     "Produkt '#{product_name_by_admin}' wurde nicht in der DB gefunden, nachdem Admin es erstellt hat."
      admin_product_id = created_product.product_id

      expect(admin_product_id).not_to be_nil, 'Keine Produkt-ID erhalten, nachdem Admin das Produkt erstellt hat.'

      logout

      login_as(regular_user)

      update_product_via_api(admin_product_id, 'Updated by Regular User')

      expect(response_status).to eq(403)
    end
  end
end
