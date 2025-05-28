# frozen_string_literal: true

# spec/routes/license_management_spec.rb
require_relative '../spec_helper'

RSpec.describe 'License Management Routes' do
  include Rack::Test::Methods

  let!(:admin_user) { create_admin_user(username: 'admin_lic_mgr', email: 'admin_lic_mgr@example.com') }
  let!(:regular_user) { create_regular_user(username: 'user_lic_mgr', email: 'user_lic_mgr@example.com') }
  let!(:product1) { create_product_via_dao(name: 'Software X') }
  let!(:license_type1) { create_license_type_via_dao(name: 'Subscription') }

  let(:valid_license_attributes) do
    {
      product_id: product1.product_id,
      license_type_id: license_type1.license_type_id,
      license_key: 'VALID-KEY-123',
      license_name: 'Software X Annual Subscription',
      seat_count: 10,
      purchase_date: Date.today.to_s,
      expire_date: (Date.today + 365).to_s,
      cost: '99.99',
      currency: 'USD',
      vendor: 'Software Corp',
      notes: 'Annual team license',
      status: 'active'
    }
  end

  let(:invalid_license_attributes) do
    valid_license_attributes.merge(license_key: nil, product_id: nil) # Ungültiger Key und Product ID
  end

  shared_examples 'admin access only' do |method, path_template, params = {}|
    it 'redirects unauthenticated users to login' do
      logout # Stelle sicher, dass kein Benutzer angemeldet ist
      send(method, path_template.is_a?(Proc) ? path_template.call : path_template, params)
      expect(last_response.status).to eq(302) # Annahme: Umleitung zum Login
      expect(last_response.location).to include('/login')
    end

    it 'returns 403 for non-admin users' do
      login_as(regular_user)
      send(method, path_template.is_a?(Proc) ? path_template.call : path_template, params)
      expect(last_response.status).to eq(403) # Annahme: Forbidden-Status
      # Optional: Überprüfe Flash-Nachricht oder Body
      # expect(flash[:error]).to include("You are not authorized to access this page")
    end
  end

  describe 'GET /admin/licenses' do
    let(:path) { '/admin/licenses' }

    include_examples 'admin access only', :get, '/admin/licenses'

    context 'when logged in as admin' do
      before do
        create_license_via_dao( # Erstelle einige Lizenzen, um sie in der Ansicht anzuzeigen
          product: product1,
          license_type: license_type1,
          license_key: 'TESTKEY001',
          license_name: 'Test License 1'
        )
        login_as(admin_user)
        get path
      end

      it 'returns a 200 OK status' do
        expect(last_response.status).to eq(200)
      end

      it 'renders the license management page' do
        expect(last_response.body).to include('License Management') # Oder ein spezifischerer Text
        expect(last_response.body).to include(product1.product_name)
        expect(last_response.body).to include(license_type1.license_type_name)
        expect(last_response.body).to include('TESTKEY001')
      end
    end
  end

  describe 'POST /admin/licenses' do
    let(:path) { '/admin/licenses' }

    include_examples 'admin access only', :post, '/admin/licenses', { license_key: 'test' }

    context 'when logged in as admin' do
      before { login_as(admin_user) }

      context 'with valid data' do
        it 'creates a new license' do
          expect do
            post path, valid_license_attributes
          end.to change(License, :count).by(1)
        end

        it 'returns a 200 OK status' do
          post path, valid_license_attributes
          expect(last_response.status).to eq(200)
        end

        it 'sets a success flash message' do
          post path, valid_license_attributes
          expect(flash[:success]).to eq('License successfully created')
        end
      end

      context 'with invalid data' do
        it 'does not create a new license' do
          expect do
            post path, invalid_license_attributes
          end.not_to change(License, :count)
        end

        it 'returns a 422 Unprocessable Entity status' do
          post path, invalid_license_attributes
          expect(last_response.status).to eq(422)
        end

        it 'sets an error flash message with validation errors' do
          # Simuliere DAO::ValidationError
          errors_mock = double('errors', full_messages: ["License key can't be blank", 'Product must exist'])
          validation_error = DAO::ValidationError.new('Validation failed')
          allow(validation_error).to receive(:errors).and_return(errors_mock)
          allow(LicenseDAO).to receive(:create).and_raise(validation_error)

          post path, invalid_license_attributes
          expect(flash[:error]).to eq("License key can't be blank,Product must exist")
        end
      end

      context 'when a generic error occurs' do
        before do
          allow(LicenseDAO).to receive(:create).and_raise(StandardError.new('Database connection lost'))
        end

        it 'returns a 500 Internal Server Error status' do
          post path, valid_license_attributes
          expect(last_response.status).to eq(500)
        end

        it 'sets a generic error flash message' do
          post path, valid_license_attributes
          expect(flash[:error]).to eq('Error creating license: Database connection lost')
        end
      end
    end
  end

  describe 'PUT /admin/licenses/:id' do
    let!(:existing_license) { create_license_via_dao(valid_license_attributes) }
    let(:path_proc) { -> { "/admin/licenses/#{existing_license.id}" } } # Proc für lazy evaluation

    include_examples 'admin access only', :put, lambda {
      "/admin/licenses/#{existing_license.id}"
    }, { license_name: 'updated' }

    context 'when logged in as admin' do
      before { login_as(admin_user) }

      context 'with valid data' do
        let(:updated_attributes) { { license_name: 'Updated License Name', seat_count: 20 } }

        it 'updates the license' do
          put path_proc.call, updated_attributes.merge(product_id: existing_license.product_id, license_type_id: existing_license.license_type_id) # Sende alle benötigten Felder
          existing_license.reload
          expect(existing_license.license_name).to eq('Updated License Name')
          expect(existing_license.seat_count).to eq(20)
        end

        it 'returns a 200 OK status' do
          put path_proc.call,
              updated_attributes.merge(product_id: existing_license.product_id,
                                       license_type_id: existing_license.license_type_id)
          expect(last_response.status).to eq(200)
        end

        it 'sets a success flash message' do
          put path_proc.call,
              updated_attributes.merge(product_id: existing_license.product_id,
                                       license_type_id: existing_license.license_type_id)
          expect(flash[:success]).to eq('License successfully updated')
        end
      end

      context 'with invalid data' do
        let(:invalid_update_attributes) { { license_name: '', seat_count: -5 } }

        it 'does not update the license attributes to invalid values' do
          original_name = existing_license.license_name
          put path_proc.call,
              invalid_update_attributes.merge(product_id: existing_license.product_id,
                                              license_type_id: existing_license.license_type_id)
          expect(existing_license.reload.license_name).to eq(original_name) # Sollte nicht geändert werden
        end

        it 'returns a 422 Unprocessable Entity status' do
          # Simuliere DAO::ValidationError
          errors_mock = double('errors', full_messages: ["License name can't be blank"])
          validation_error = DAO::ValidationError.new('Validation failed')
          allow(validation_error).to receive(:errors).and_return(errors_mock)
          allow(LicenseDAO).to receive(:update).and_raise(validation_error)

          put path_proc.call,
              invalid_update_attributes.merge(product_id: existing_license.product_id,
                                              license_type_id: existing_license.license_type_id)
          expect(last_response.status).to eq(422)
        end

        it 'sets an error flash message with validation errors' do
          errors_mock = double('errors', full_messages: ["License name can't be blank"])
          validation_error = DAO::ValidationError.new('Validation failed')
          allow(validation_error).to receive(:errors).and_return(errors_mock)
          allow(LicenseDAO).to receive(:update).and_raise(validation_error)

          put path_proc.call,
              invalid_update_attributes.merge(product_id: existing_license.product_id,
                                              license_type_id: existing_license.license_type_id)
          expect(flash[:error]).to eq("License name can't be blank")
        end
      end

      context 'when a generic error occurs' do
        before do
          allow(LicenseDAO).to receive(:update).and_raise(StandardError.new('Concurrency issue'))
        end

        it 'returns a 500 Internal Server Error status' do
          put path_proc.call,
              { license_name: 'test' }.merge(product_id: existing_license.product_id,
                                             license_type_id: existing_license.license_type_id)
          expect(last_response.status).to eq(500)
        end

        it 'sets a generic error flash message' do
          put path_proc.call,
              { license_name: 'test' }.merge(product_id: existing_license.product_id,
                                             license_type_id: existing_license.license_type_id)
          expect(flash[:error]).to eq('Error updating license: Concurrency issue')
        end
      end
    end
  end

  describe 'DELETE /admin/licenses/:id' do
    let!(:license_to_delete) { create_license_via_dao(valid_license_attributes) }
    let(:path_proc) { -> { "/admin/licenses/#{license_to_delete.id}" } }

    include_examples 'admin access only', :delete, -> { "/admin/licenses/#{license_to_delete.id}" }

    context 'when logged in as admin' do
      before { login_as(admin_user) }

      context 'when deletion is successful' do
        it 'deletes the license' do
          expect do
            delete path_proc.call
          end.to change(License, :count).by(-1)
        end

        it 'returns a 200 OK status' do
          delete path_proc.call
          expect(last_response.status).to eq(200)
        end

        it 'sets a success flash message' do
          delete path_proc.call
          expect(flash[:success]).to eq('License successfully deleted')
        end
      end

      context 'when deletion fails (e.g., due to associated records or DAO validation)' do
        before do
          # Simuliere einen Fehler beim Löschen, z.B. eine DAO::ValidationError
          errors_mock = double('errors', full_messages: ['Cannot delete license with active assignments'])
          validation_error = DAO::ValidationError.new('Deletion failed')
          allow(validation_error).to receive(:errors).and_return(errors_mock)
          allow(LicenseDAO).to receive(:delete).with(license_to_delete.id.to_s).and_raise(validation_error)
        end

        it 'does not delete the license' do
          expect do
            delete path_proc.call
          end.not_to change(License, :count)
        end

        it 'returns a 422 Unprocessable Entity status' do
          delete path_proc.call
          expect(last_response.status).to eq(422)
        end

        it 'sets an error flash message' do
          delete path_proc.call
          expect(flash[:error]).to eq('Cannot delete license with active assignments')
        end
      end

      context 'when a generic error occurs during deletion' do
        before do
          allow(LicenseDAO).to receive(:delete).with(license_to_delete.id.to_s).and_raise(StandardError.new('Filesystem error'))
        end

        it 'returns a 500 Internal Server Error status' do
          delete path_proc.call
          expect(last_response.status).to eq(500)
        end

        it 'sets a generic error flash message' do
          delete path_proc.call
          expect(flash[:error]).to eq('Error deleting license: Filesystem error')
        end
      end

      context 'when trying to delete a non-existent license' do
        before do
          # Stelle sicher, dass LicenseDAO.delete eine DAO::RecordNotFound wirft, wenn der Datensatz nicht existiert.
          # Wenn es nur false zurückgibt oder einen allgemeinen Fehler, passe dies an.
          # Hier wird angenommen, dass ein Standardfehler ausgelöst wird, der in einen 500-Status umgewandelt wird.
          allow(LicenseDAO).to receive(:delete).with('nonexistentid').and_raise(DAO::RecordNotFound.new('License not found'))
        end

        it 'returns a 500 status (oder 404, je nach Fehlerbehandlung in der Route)' do
          # Die aktuelle Route fängt DAO::RecordNotFound nicht explizit ab, daher wird es als StandardError behandelt => 500
          delete '/admin/licenses/nonexistentid'
          expect(last_response.status).to eq(500)
        end

        it 'sets an error flash message' do
          delete '/admin/licenses/nonexistentid'
          expect(flash[:error]).to include('Error deleting license: License not found')
        end
      end
    end
  end
end
