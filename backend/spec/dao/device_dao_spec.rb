require 'spec_helper'

RSpec.describe DeviceDAO do

  let(:valid_attributes) { Fabricate.attributes_for(:device) }
  let(:device1) { Fabricate(:device) }
  let(:device2) { Fabricate(:device) }

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new device in the database' do
        expect {
          described_class.create(valid_attributes)
        }.to change(Device, :count).by(1)
      end

      it 'returns the created device object' do
        device = described_class.create(valid_attributes)
        expect(device).to be_a(Device)
        expect(device.device_name).to eq(valid_attributes[:device_name])
        expect(device.pk).not_to be_nil
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_created)
        described_class.create(valid_attributes)
        expect(described_class).to have_received(:log_created).with(an_instance_of(Device))
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { Fabricate.attributes_for(:device, device_name: nil) }

      it 'does not create a new device' do
        expect {
          begin
            described_class.create(invalid_attributes)
          rescue DAO::ValidationError
          end
        }.not_to change(Device, :count)
      end

      it 'raises a ValidationError' do
        expect {
          described_class.create(invalid_attributes)
        }.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating device/i)
          expect(error.errors).to have_key(:device_name)
          expect(error.errors[:device_name]).to include(/device name can not be empty/i)
        end
      end

      it 'logs the validation failure' do
         allow(described_class).to receive(:log_validation_failed)
         expect { described_class.create(invalid_attributes) }.to raise_error(DAO::ValidationError)
         expect(described_class).to have_received(:log_validation_failed).with(an_instance_of(Device), /creating device/i)
      end
    end

    context 'with duplicate serial number (when not nil)' do
       let!(:existing_device) { Fabricate(:device, serial_number: 'DUPLICATE-SN') }
       let(:duplicate_attributes) { Fabricate.attributes_for(:device, serial_number: 'DUPLICATE-SN') }

       it 'raises a ValidationError' do
         expect {
           described_class.create(duplicate_attributes)
         }.to raise_error(DAO::ValidationError) do |error|
           expect(error.errors).to have_key(:serial_number)
           expect(error.errors[:serial_number]).to include(/serial number must be unique if specified/i)
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
      let(:non_existent_id) { 99999 }

      it 'raises a RecordNotFound error' do
        expect {
          described_class.find!(non_existent_id)
        }.to raise_error(DAO::RecordNotFound, /Device with ID #{non_existent_id} not found/i)
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
         expect(described_class.find(99999)).to be_nil
       end
     end
   end

  describe '.all' do
    before do
      Device.dataset.delete
      device1; device2
    end

    it 'returns all existing devices' do
      devices = described_class.all
      expect(devices.count).to eq(2)
      expect(devices).to include(device1, device2)
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

     context 'with valid attributes' do
       it 'updates the device attributes in the database' do
         updated_device = described_class.update(device_to_update.pk, update_attributes)
         device_to_update.refresh
         expect(device_to_update.device_name).to eq('New Name')
         expect(updated_device.device_name).to eq('New Name')
       end

       it 'returns the updated device object' do
          updated_device = described_class.update(device_to_update.pk, update_attributes)
          expect(updated_device).to be_a(Device)
          expect(updated_device.pk).to eq(device_to_update.pk)
       end

       it 'logs the update' do
          allow(described_class).to receive(:log_updated)
          described_class.update(device_to_update.pk, update_attributes)
          expect(described_class).to have_received(:log_updated).with(device_to_update)
       end
     end

     context 'with invalid attributes' do
        let(:invalid_update_attributes) { { device_name: '' } }

       it 'does not update the device' do
          expect {
            begin
              described_class.update(device_to_update.pk, invalid_update_attributes)
            rescue DAO::ValidationError
            end
          }.not_to change { device_to_update.refresh.device_name }
       end

       it 'raises a ValidationError' do
          expect {
            described_class.update(device_to_update.pk, invalid_update_attributes)
          }.to raise_error(DAO::ValidationError) do |error|
             expect(error.errors[:device_name]).to include(/device name can not be empty/i)
          end
       end
     end

     context 'when the device does not exist' do
        it 'raises a RecordNotFound error' do
          expect {
            described_class.update(99999, update_attributes)
          }.to raise_error(DAO::RecordNotFound)
        end
     end
   end

   describe '.delete' do
      let!(:device_to_delete) { Fabricate(:device) }
      let(:device_id) { device_to_delete.pk }

      it 'removes the device from the database' do
        expect {
          described_class.delete(device_id)
        }.to change(Device, :count).by(-1)
      end

      it 'returns true' do
         expect(described_class.delete(device_id)).to be true
      end

       it 'logs the deletion' do
          allow(described_class).to receive(:log_deleted)
          described_class.delete(device_id)
          expect(described_class).to have_received(:log_deleted).with(device_to_delete)
       end

      context 'when the device does not exist' do
         it 'raises a RecordNotFound error' do
           expect {
             described_class.delete(99999)
           }.to raise_error(DAO::RecordNotFound)
         end
      end
   end

  describe '.find_by_serial_number' do
      let!(:device_with_sn) { Fabricate(:device, serial_number: 'ABC123XYZ') }
      let!(:device_without_sn) { Fabricate(:device, serial_number: nil) }

      context 'when a device with the given serial number exists' do
         it 'returns the device object' do
            expect(described_class.find_by_serial_number('ABC123XYZ')).to eq(device_with_sn)
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
