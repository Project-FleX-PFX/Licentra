# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../app'

RSpec.describe 'Product Management' do
  include Rack::Test::Methods

  def app
    LicentraApp.new
  end

  def session
    last_request.env['rack.session']
  end

  # --- Test Data Setup using Fabricators ---
  let!(:admin_role) { Fabricate(:role, role_name: 'Admin') }
  let!(:user_role)  { Fabricate(:role, role_name: 'User') }

  let!(:admin_user) do
    user = Fabricate(:user,
                     username: 'admin_test',
                     email: 'admin_test@example.com',
                     first_name: 'Admin',
                     last_name: 'Test',
                     is_active: true)
    Fabricate(:user_credential, user: user, password: 'password123')
    user.add_role(admin_role)
    user.add_role(user_role)
    user.refresh
    user
  end

  # Helper-Methode zum Einloggen als Admin
  def login_as_admin
    post '/login', { email: admin_user.email, password: 'password123' }
    follow_redirect! while last_response.redirect?
  end

  # Helper-Methode zum Erstellen eines Produkts
  def create_product(name)
    post '/product_management', { product_name: name }
  end

  # Helper-Methode zum Aktualisieren eines Produkts
  def update_product(id, name)
    put "/product_management/#{id}", { product_name: name }
  end

  before(:each) do
    # Datenbank für jeden Test zurücksetzen
    Product.dataset.delete
    login_as_admin
  end

  describe 'GET /product_management' do
    it 'zeigt die Produktverwaltungsseite an' do
      get '/product_management'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Product Management')
    end

    it 'verweigert Zugriff für nicht-authentifizierte Benutzer' do
      # Ausloggen
      get '/logout'
      expect(last_response).to be_redirect
      
      # Versuch, auf die Produktverwaltung zuzugreifen
      get '/product_management'
      expect(last_response).to be_redirect
      expect(last_response.location).to include('/login')
    end

    it 'zeigt alle vorhandenen Produkte an' do
      # Produkte erstellen
      ProductDAO.create(product_name: 'Test Product 1')
      ProductDAO.create(product_name: 'Test Product 2')
      
      get '/product_management'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Product 1')
      expect(last_response.body).to include('Test Product 2')
    end
  end

  describe 'POST /product_management' do
    it 'erstellt ein neues Produkt' do
      create_product('New Product')
      expect(last_response.status).to eq(200)
      
      # Überprüfen, ob das Produkt in der Datenbank existiert
      product = Product.first(product_name: 'New Product')
      expect(product).not_to be_nil
    end

    it 'verhindert die Erstellung von Produkten mit doppeltem Namen' do
      # Erstes Produkt erstellen
      create_product('Duplicate Product')
      expect(last_response.status).to eq(200)
      
      # Versuch, ein Produkt mit demselben Namen zu erstellen
      create_product('Duplicate Product')
      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('already taken')
    end
  end

  describe 'PUT /product_management/:id' do
    it 'aktualisiert ein bestehendes Produkt' do
      # Produkt erstellen
      product = ProductDAO.create(product_name: 'Original Name')
      
      # Produkt aktualisieren
      update_product(product.product_id, 'Updated Name')
      expect(last_response.status).to eq(200)
      
      # Überprüfen, ob der Name aktualisiert wurde
      updated_product = Product.first(product_id: product.product_id)
      expect(updated_product.product_name).to eq('Updated Name')
    end

    it 'verhindert die Aktualisierung zu einem bereits verwendeten Namen' do
      # Zwei Produkte erstellen
      product1 = ProductDAO.create(product_name: 'Product One')
      product2 = ProductDAO.create(product_name: 'Product Two')
      
      # Versuch, product2 auf denselben Namen wie product1 zu aktualisieren
      update_product(product2.product_id, 'Product One')
      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('already taken')
    end

    it 'gibt einen Fehler zurück, wenn das Produkt nicht existiert' do
      update_product(999, 'Nonexistent Product')
      expect(last_response.status).to eq(500)
      expect(last_response.body).to include('Error updating product')
    end
  end

  describe 'Zugriffskontrolle für nicht-Admin-Benutzer' do
    let!(:regular_user) do
      user = Fabricate(:user,
                       username: 'user_test',
                       email: 'user_test@example.com',
                       first_name: 'User',
                       last_name: 'Test',
                       is_active: true)
      Fabricate(:user_credential, user: user, password: 'password123')
      user.add_role(user_role)
      user.refresh
      user
    end

    def login_as_regular_user
      post '/login', { email: regular_user.email, password: 'password123' }
      follow_redirect! while last_response.redirect?
    end

    it 'verweigert normalen Benutzern den Zugriff auf die Produktverwaltung' do
      # Ausloggen und als normaler Benutzer einloggen
      get '/logout'
      login_as_regular_user
      
      # Versuche, auf die Produktverwaltung zuzugreifen
      get '/product_management'
      expect(last_response.status).to eq(403) # Forbidden
    end

    it 'verweigert normalen Benutzern das Erstellen von Produkten' do
      # Ausloggen und als normaler Benutzer einloggen
      get '/logout'
      login_as_regular_user
      
      # Versuche, ein Produkt zu erstellen
      create_product('Regular User Product')
      expect(last_response.status).to eq(403) # Forbidden
    end

    it 'verweigert normalen Benutzern das Aktualisieren von Produkten' do
      # Als Admin ein Produkt erstellen
      get '/logout'
      login_as_admin
      product = ProductDAO.create(product_name: 'Admin Product')
      
      # Ausloggen und als normaler Benutzer einloggen
      get '/logout'
      login_as_regular_user
      
      # Versuche, das Produkt zu aktualisieren
      update_product(product.product_id, 'Updated by Regular User')
      expect(last_response.status).to eq(403) # Forbidden
    end
  end
end

