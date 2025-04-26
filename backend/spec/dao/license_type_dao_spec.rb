# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseTypeDAO do
  let(:valid_attributes) do
    Fabricate.attributes_for(:license_type)
  end
  let!(:license_type1) { Fabricate(:license_type, type_name: 'Perpetual') }
  let!(:license_type2) { Fabricate(:license_type, type_name: 'Subscription') }

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new license type' do
        expect do
          described_class.create(valid_attributes)
        end.to change(LicenseType, :count).by(1)
      end

      it 'returns the created license type object', :aggregate_failures do
        license_type = described_class.create(valid_attributes)
        expect(license_type).to be_a(LicenseType)
        expect(license_type.type_name).to eq(valid_attributes[:type_name])
        expect(license_type.pk).not_to be_nil
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_created)
        license_type = described_class.create(valid_attributes)
        expect(described_class).to have_received(:log_created).with(license_type)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { type_name: nil } }

      it 'does not create a new license type' do
        expect do
          described_class.create(invalid_attributes)
        rescue StandardError
          # Expected error
        end.not_to change(LicenseType, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating license type/i)
          expect(error.errors).to have_key(:type_name)
        end
      end
    end
  end

  describe '.find_by_name' do
    it 'returns the license type when found' do
      license_type = described_class.find_by_name('Perpetual')
      expect(license_type).to eq(license_type1)
    end

    it 'returns nil when license type not found' do
      expect(described_class.find_by_name('Nonexistent Type')).to be_nil
    end

    it 'returns nil when name is nil or empty' do
      expect(described_class.find_by_name(nil)).to be_nil
      expect(described_class.find_by_name('')).to be_nil
    end

    it 'logs when license type is found' do
      allow(described_class).to receive(:log_license_type_found_by_name)
      described_class.find_by_name('Perpetual')
      expect(described_class).to have_received(:log_license_type_found_by_name).with('Perpetual', license_type1)
    end

    it 'does not log when license type is not found' do
      allow(described_class).to receive(:log_license_type_found_by_name)
      described_class.find_by_name('Nonexistent Type')
      expect(described_class).not_to have_received(:log_license_type_found_by_name)
    end
  end

  describe '.find_by_name!' do
    it 'returns the license type when found' do
      license_type = described_class.find_by_name!('Perpetual')
      expect(license_type).to eq(license_type1)
    end

    it 'raises RecordNotFound when license type not found' do
      expect do
        described_class.find_by_name!('Nonexistent Type')
      end.to raise_error(DAO::RecordNotFound)
    end
  end

  describe '.delete' do
    context 'when license type has no licenses' do
      let!(:license_type_to_delete) { Fabricate(:license_type) }

      it 'removes the license type from the database' do
        expect do
          described_class.delete(license_type_to_delete.pk)
        end.to change(LicenseType, :count).by(-1)
        expect(LicenseType[license_type_to_delete.pk]).to be_nil
      end

      it 'returns true' do
        expect(described_class.delete(license_type_to_delete.pk)).to be true
      end

      it 'logs the deletion' do
        allow(described_class).to receive(:log_deleted)
        described_class.delete(license_type_to_delete.pk)
        expect(described_class).to have_received(:log_deleted).with(license_type_to_delete)
      end
    end

    context 'when license type has licenses' do
      let!(:license_type_with_licenses) { Fabricate(:license_type) }

      before do
        Fabricate(:license, license_type: license_type_with_licenses)
      end

      it 'does not delete the license type' do
        expect do
          described_class.delete(license_type_with_licenses.pk)
        rescue StandardError
          # Expected error
        end.not_to change(LicenseType, :count)
      end

      it 'raises a DatabaseError' do
        expect do
          described_class.delete(license_type_with_licenses.pk)
        end.to raise_error(DAO::DatabaseError, /Cannot delete/i)
      end
    end

    context 'when license type does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.delete(99_999)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end
end
