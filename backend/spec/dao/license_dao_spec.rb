# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseDAO do
  let(:product) { Fabricate(:product) }
  let(:license_type) { Fabricate(:license_type) }
  let(:valid_attributes) do
    attrs = Fabricate.attributes_for(:license)
    attrs[:product_id] = product.product_id
    attrs[:license_type_id] = license_type.license_type_id
    attrs
  end

  let!(:license1) { Fabricate(:license, product: product, license_key: 'LICENSE-1') }
  let!(:license2) { Fabricate(:license, license_type: license_type, license_key: 'LICENSE-2') }

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new license' do
        expect do
          described_class.create(valid_attributes)
        end.to change(License, :count).by(1)
      end

      it 'returns the created license object', :aggregate_failures do
        license = described_class.create(valid_attributes)
        expect(license).to be_a(License)
        expect(license.product_id).to eq(product.pk)
        expect(license.license_type_id).to eq(license_type.pk)
        expect(license.pk).not_to be_nil
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_created)
        license = described_class.create(valid_attributes)
        expect(described_class).to have_received(:log_created).with(license)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { valid_attributes.merge(seat_count: 0) }

      it 'does not create a new license' do
        expect do
          described_class.create(invalid_attributes)
        rescue StandardError
          # Expected error
        end.not_to change(License, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating license/i)
          expect(error.errors).to have_key(:seat_count)
        end
      end
    end
  end

  describe '.find!' do
    context 'when the license exists' do
      it 'returns the license object' do
        found = described_class.find!(license1.pk)
        expect(found).to eq(license1)
      end

      it 'logs the find operation' do
        allow(described_class).to receive(:log_found)
        described_class.find!(license1.pk)
        expect(described_class).to have_received(:log_found).with(license1)
      end
    end

    context 'when the license does not exist' do
      let(:non_existent_id) { 99_999 }

      it 'raises a RecordNotFound error' do
        expect do
          described_class.find!(non_existent_id)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.find' do
    it 'returns the license object if it exists' do
      expect(described_class.find(license1.pk)).to eq(license1)
    end

    it 'returns nil if the license does not exist' do
      expect(described_class.find(99_999)).to be_nil
    end
  end

  describe '.all' do
    before do
      License.dataset.delete
      @license1 = Fabricate(:license, license_key: 'LICENSE-A')
      @license2 = Fabricate(:license, license_key: 'LICENSE-B')
    end

    it 'returns all existing licenses', :aggregate_failures do
      licenses = described_class.all
      expect(licenses.count).to eq(2)
      expect(licenses).to include(@license1, @license2)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_fetched)
      described_class.all
      expect(described_class).to have_received(:log_fetched).with(2)
    end
  end

  describe '.update' do
    let!(:license_to_update) { Fabricate(:license, license_key: 'OLD-KEY') }
    let(:update_attributes) { { license_key: 'NEW-KEY', seat_count: 10 } }

    context 'with valid attributes' do
      it 'updates the license attributes', :aggregate_failures do
        updated_license = described_class.update(license_to_update.pk, update_attributes)
        license_to_update.refresh
        expect(license_to_update.license_key).to eq('NEW-KEY')
        expect(license_to_update.seat_count).to eq(10)
        expect(updated_license.license_key).to eq('NEW-KEY')
      end

      it 'logs the update' do
        allow(described_class).to receive(:log_updated)
        described_class.update(license_to_update.pk, update_attributes)
        expect(described_class).to have_received(:log_updated).with(license_to_update)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_update_attributes) { { seat_count: 0 } }

      it 'does not update the license' do
        expect do
          described_class.update(license_to_update.pk, invalid_update_attributes)
        rescue StandardError
          # Expected error
        end.not_to(change { license_to_update.refresh.seat_count })
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.update(license_to_update.pk, invalid_update_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.errors).to have_key(:seat_count)
        end
      end
    end

    context 'when the license does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.update(99_999, license_key: 'something')
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.delete' do
    let!(:license_to_delete) { Fabricate(:license) }
    let(:license_id) { license_to_delete.pk }

    context 'when the license has no active assignments' do
      it 'removes the license from the database' do
        expect do
          described_class.delete(license_id)
        end.to change(License, :count).by(-1)
        expect(License[license_id]).to be_nil
      end

      it 'returns true' do
        expect(described_class.delete(license_id)).to be true
      end

      it 'logs the deletion' do
        allow(described_class).to receive(:log_license_deleted)
        described_class.delete(license_id)
        expect(described_class).to have_received(:log_license_deleted).with(license_to_delete)
      end
    end

    context 'when the license has active assignments' do
      before do
        # Create an active assignment for the license
        Fabricate(:license_assignment, license: license_to_delete, is_active: true)
      end

      it 'does not delete the license' do
        expect do
          described_class.delete(license_id)
        rescue StandardError
          # Expected error
        end.not_to change(License, :count)
      end

      it 'raises a LicenseManagementError' do
        expect do
          described_class.delete(license_id)
        end.to raise_error(DAO::LicenseManagementError, /active assignments exist/i)
      end
    end

    context 'when the license does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.delete(99_999)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.find_by_product' do
    let!(:specific_product) { Fabricate(:product, product_name: 'Test Product') }
    let!(:license_for_product1) { Fabricate(:license, product: specific_product) }
    let!(:license_for_product2) { Fabricate(:license, product: specific_product) }
    let!(:other_license) { Fabricate(:license) }

    it 'returns licenses for the specified product' do
      licenses = described_class.find_by_product(specific_product.pk)
      expect(licenses).to include(license_for_product1, license_for_product2)
      expect(licenses).not_to include(other_license)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_licenses_for_product_fetched)
      described_class.find_by_product(specific_product.pk)
      expect(described_class).to have_received(:log_licenses_for_product_fetched)
        .with(specific_product.pk, an_instance_of(Integer))
    end
  end

  describe '.find_by_license_type' do
    let!(:specific_type) { Fabricate(:license_type, type_name: 'Test Type') }
    let!(:license_for_type1) { Fabricate(:license, license_type: specific_type) }
    let!(:license_for_type2) { Fabricate(:license, license_type: specific_type) }
    let!(:other_license) { Fabricate(:license) }

    it 'returns licenses for the specified license type' do
      licenses = described_class.find_by_license_type(specific_type.pk)
      expect(licenses).to include(license_for_type1, license_for_type2)
      expect(licenses).not_to include(other_license)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_licenses_for_type_fetched)
      described_class.find_by_license_type(specific_type.pk)
      expect(described_class).to have_received(:log_licenses_for_type_fetched)
        .with(specific_type.pk, an_instance_of(Integer))
    end
  end
end
