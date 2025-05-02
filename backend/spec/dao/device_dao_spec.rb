# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeviceDAO do
  let(:valid_attributes) { Fabricate.attributes_for(:device) }
  let!(:device1) { Fabricate(:device) }
  let!(:device2) { Fabricate(:device) }

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new device' do
        expect do
          described_class.create(valid_attributes)
        end.to change(Device, :count).by(1)
      end

      it 'returns the created device object', :aggregate_failures do
        device = described_class.create(valid_attributes)
        expect(device).to be_a(Device)
        expect(device.device_name).to eq(valid_attributes[:device_name])
        expect(device.pk).not_to be_nil
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_created)
        created_device = described_class.create(Fabricate.attributes_for(:device))
        expect(described_class).to have_received(:log_created).with(created_device)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { Fabricate.attributes_for(:device, device_name: nil) }

      it 'does not create a new device' do
        expect do
          described_class.create(invalid_attributes)
        rescue StandardError
          DAO::ValidationError
        end.not_to change(Device, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating device/i)
          expect(error.errors).to have_key(:device_name)
          expect(error.errors[:device_name]).to include('device name can not be empty')
        end
      end

      it 'logs the validation failure' do
        allow(described_class).to receive(:log_validation_failed)
        expect { described_class.create(invalid_attributes) }.to raise_error(DAO::ValidationError)
        expect(described_class).to have_received(:log_validation_failed).with(an_instance_of(Device),
                                                                              /creating device/i)
      end
    end

    context 'with duplicate serial number' do
      let!(:existing_device) { Fabricate(:device, serial_number: 'DUPLICATE-SN') }
      let(:duplicate_attributes) { Fabricate.attributes_for(:device, serial_number: 'DUPLICATE-SN') }

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(duplicate_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.errors).to have_key(:serial_number)
          expect(error.errors[:serial_number]).to include('serial number must be unique if specified')
        end
      end
    end
  end

  describe '.find!' do
    let!(:existing_device) { device1 }

    context 'when the device exists' do
      it 'returns the device object' do
        found_device = described_class.find!(existing_device.pk)
        expect(found_device).to eq(existing_device)
      end

      it 'logs the find operation' do
        allow(described_class).to receive(:log_found)
        described_class.find!(existing_device.pk)
        expect(described_class).to have_received(:log_found).with(existing_device)
      end
    end

    context 'when the device does not exist' do
      let(:non_existent_id) { 99_999 }

      it 'raises a RecordNotFound error' do
        expect do
          described_class.find!(non_existent_id)
        end.to raise_error(DAO::RecordNotFound, "Device with ID #{non_existent_id} not found")
      end

      it 'logs the record not found event' do
        allow(described_class).to receive(:log_record_not_found)
        expect { described_class.find!(non_existent_id) }.to raise_error(DAO::RecordNotFound)
        expect(described_class).to have_received(:log_record_not_found).with(non_existent_id)
      end
    end
  end

  describe '.find' do
    let!(:existing_device) { device1 }

    context 'when the device exists' do
      it 'returns the device object' do
        expect(described_class.find(existing_device.pk)).to eq(existing_device)
      end
    end

    context 'when the device does not exist' do
      it 'returns nil' do
        expect(described_class.find(99_999)).to be_nil
      end
    end
  end

  describe '.all' do
    before do
      Device.dataset.delete
      Fabricate(:device, device_name: 'Device A')
      Fabricate(:device, device_name: 'Device B')
    end

    it 'returns all existing devices', :aggregate_failures do
      devices = described_class.all
      expect(devices.count).to eq(2)
      expect(devices.map(&:device_name)).to contain_exactly('Device A', 'Device B')
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_fetched)
      described_class.all
      expect(described_class).to have_received(:log_fetched).with(2)
    end
  end

  describe '.update' do
    let!(:device_to_update) { Fabricate(:device, device_name: 'Old Name') }
    let(:update_attributes) { { device_name: 'New Name' } }
    let(:non_existent_id) { 99_999 }

    context 'with valid attributes' do
      it 'updates the device attributes', :aggregate_failures do
        updated_device = described_class.update(device_to_update.pk, update_attributes)
        device_to_update.refresh
        expect(device_to_update.device_name).to eq('New Name')
        expect(updated_device.device_name).to eq('New Name')
      end

      it 'returns the updated device object', :aggregate_failures do
        updated_device = described_class.update(device_to_update.pk, update_attributes)
        expect(updated_device).to be_a(Device)
        expect(updated_device.pk).to eq(device_to_update.pk)
      end

      it 'logs the update' do
        allow(described_class).to receive(:log_updated)
        updated_device = described_class.update(device_to_update.pk, update_attributes)
        expect(described_class).to have_received(:log_updated).with(updated_device)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_update_attributes) { { device_name: '' } }

      it 'does not update the device' do
        expect do
          described_class.update(device_to_update.pk, invalid_update_attributes)
        rescue StandardError
          DAO::ValidationError
        end.not_to(change { device_to_update.refresh.device_name })
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.update(device_to_update.pk, invalid_update_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.errors).to have_key(:device_name)
          expect(error.errors[:device_name]).to include('device name can not be empty')
        end
      end

      it 'logs the validation failure' do
        allow(described_class).to receive(:log_validation_failed)
        expect do
          described_class.update(device_to_update.pk, invalid_update_attributes)
        end.to raise_error(DAO::ValidationError)
        expect(described_class).to have_received(:log_validation_failed).with(an_instance_of(Device),
                                                                              /updating device/i)
      end
    end

    context 'when the device does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.update(non_existent_id, update_attributes)
        end.to raise_error(DAO::RecordNotFound)
      end

      it 'logs the record not found event' do
        allow(described_class).to receive(:log_record_not_found)
        expect { described_class.update(non_existent_id, update_attributes) }.to raise_error(DAO::RecordNotFound)
        expect(described_class).to have_received(:log_record_not_found).with(non_existent_id)
      end
    end
  end

  describe '.delete' do
    let!(:device_to_delete) { Fabricate(:device) }
    let(:device_id) { device_to_delete.pk }
    let(:non_existent_id) { 99_999 }

    it 'removes the device from the database', :aggregate_failures do
      expect do
        described_class.delete(device_id)
      end.to change(Device, :count).by(-1)
      expect(Device[device_id]).to be_nil
    end

    it 'returns true' do
      expect(described_class.delete(device_id)).to be true
    end

    it 'logs the deletion' do
      allow(described_class).to receive(:log_deleted)
      deleted_device_marker = device_to_delete.dup
      described_class.delete(device_id)
      expect(described_class).to have_received(:log_deleted).with(deleted_device_marker)
    end

    context 'when the device does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.delete(non_existent_id)
        end.to raise_error(DAO::RecordNotFound)
      end

      it 'logs the record not found event' do
        allow(described_class).to receive(:log_record_not_found)
        expect { described_class.delete(non_existent_id) }.to raise_error(DAO::RecordNotFound)
        expect(described_class).to have_received(:log_record_not_found).with(non_existent_id)
      end
    end
  end

  describe '.find_by_serial_number' do
    let!(:device_with_sn) { Fabricate(:device, serial_number: 'ABC123XYZ') }
    let!(:device_without_sn) { Fabricate(:device, serial_number: nil) }
    let(:criteria_sn) { { serial_number: 'ABC123XYZ' } }

    context 'when a device with the given serial number exists' do
      it 'returns the device object' do
        expect(described_class.find_by_serial_number('ABC123XYZ')).to eq(device_with_sn)
      end

      it 'logs the find by criteria operation' do
        allow(described_class).to receive(:log_found_by_criteria) # Name anpassen, falls anders
        described_class.find_by_serial_number('ABC123XYZ')
        expect(described_class).to have_received(:log_found_by_criteria).with(criteria_sn, device_with_sn)
      end
    end

    context 'when no device with the given serial number exists' do
      it 'returns nil' do
        expect(described_class.find_by_serial_number('NONEXISTENT')).to be_nil
      end
    end

    context 'when the serial number is nil' do
      it 'returns nil' do
        expect(described_class.find_by_serial_number(nil)).to be_nil
      end
    end
  end
end
