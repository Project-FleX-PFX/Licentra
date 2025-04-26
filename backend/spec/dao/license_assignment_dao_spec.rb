# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseAssignmentDAO do
  let(:license) { Fabricate(:license) }
  let(:user) { Fabricate(:user) }
  let(:device) { Fabricate(:device) }

  let(:valid_user_assignment_attributes) do
    attrs = Fabricate.attributes_for(:license_assignment)
    attrs[:license_id] = license.license_id
    attrs[:user_id] = user.user_id
    attrs.delete(:device_id)
    attrs
  end

  let(:valid_device_assignment_attributes) do
    attrs = Fabricate.attributes_for(:license_assignment)
    attrs[:license_id] = license.license_id
    attrs[:device_id] = device.device_id
    attrs.delete(:user_id)
    attrs
  end

  let!(:user_assignment) { Fabricate(:license_assignment, license: license, user: user) }
  let!(:device_assignment) { Fabricate(:license_assignment, license: license, assign_to_user: false) }

  describe '.create' do
    context 'with valid user assignment attributes' do
      it 'creates a new license assignment' do
        expect do
          described_class.create(valid_user_assignment_attributes)
        end.to change(LicenseAssignment, :count).by(1)
      end

      it 'returns the created assignment object', :aggregate_failures do
        assignment = described_class.create(valid_user_assignment_attributes)
        expect(assignment).to be_a(LicenseAssignment)
        expect(assignment.license_id).to eq(license.license_id)
        expect(assignment.user_id).to eq(user.user_id)
        expect(assignment.device_id).to be_nil
        expect(assignment.is_active).to be true
      end

      it 'sets default values for assignment_date and is_active' do
        attrs = valid_user_assignment_attributes.dup
        attrs.delete(:assignment_date)
        attrs.delete(:is_active)

        assignment = described_class.create(attrs)
        expect(assignment.assignment_date).not_to be_nil
        expect(assignment.is_active).to be true
      end

      it 'creates an assignment log entry' do
        expect do
          described_class.create(valid_user_assignment_attributes)
        end.to change(AssignmentLog, :count).by(1)
      end
    end

    context 'with valid device assignment attributes' do
      it 'creates a new license assignment for a device' do
        assignment = described_class.create(valid_device_assignment_attributes)
        expect(assignment.device_id).to eq(device.device_id)
        expect(assignment.user_id).to be_nil
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { valid_user_assignment_attributes.merge(license_id: nil) }

      it 'does not create a new assignment' do
        expect do
          described_class.create(invalid_attributes)
        rescue StandardError
          # Expected error
        end.not_to change(LicenseAssignment, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating license assignment/i)
          expect(error.errors).to have_key(:license_id)
        end
      end
    end
  end

  describe '.find_by_license' do
    let!(:specific_license) { Fabricate(:license) }
    let!(:assignment1) { Fabricate(:license_assignment, license: specific_license) }
    let!(:assignment2) { Fabricate(:license_assignment, license: specific_license, assign_to_user: false) }

    it 'returns assignments for the specified license' do
      assignments = described_class.find_by_license(specific_license.license_id)
      expect(assignments).to include(assignment1, assignment2)
      expect(assignments).not_to include(user_assignment)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_license_fetched)
      described_class.find_by_license(specific_license.license_id)
      expect(described_class).to have_received(:log_assignments_for_license_fetched)
        .with(specific_license.license_id, 2)
    end
  end

  describe '.find_by_user' do
    let!(:specific_user) { Fabricate(:user) }
    let!(:user_assignment1) { Fabricate(:license_assignment) }
    let!(:user_assignment2) { Fabricate(:license_assignment) }

    before do
      user_assignment1.update(user_id: specific_user.user_id)
      user_assignment2.update(user_id: specific_user.user_id)
    end

    it 'returns assignments for the specified user' do
      assignments = described_class.find_by_user(specific_user.user_id)
      expect(assignments).to include(user_assignment1, user_assignment2)
      expect(assignments).not_to include(device_assignment)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_user_fetched)
      described_class.find_by_user(specific_user.user_id)
      expect(described_class).to have_received(:log_assignments_for_user_fetched)
        .with(specific_user.user_id, 2)
    end
  end

  describe '.find_by_device' do
    let!(:specific_device) { Fabricate(:device) }
    let!(:device_assignment1) { Fabricate(:license_assignment, assign_to_user: false) }
    let!(:device_assignment2) { Fabricate(:license_assignment, assign_to_user: false) }

    before do
      # Update the device_id directly to avoid callbacks
      device_assignment1.update(device_id: specific_device.device_id)
      device_assignment2.update(device_id: specific_device.device_id)
    end

    it 'returns assignments for the specified device' do
      assignments = described_class.find_by_device(specific_device.device_id)
      expect(assignments).to include(device_assignment1, device_assignment2)
      expect(assignments).not_to include(user_assignment)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_device_fetched)
      described_class.find_by_device(specific_device.device_id)
      expect(described_class).to have_received(:log_assignments_for_device_fetched)
        .with(specific_device.device_id, 2)
    end
  end

  describe '.find_active_assignments' do
    before do
      LicenseAssignment.dataset.update(is_active: false)
      @active1 = Fabricate(:license_assignment, is_active: true)
      @active2 = Fabricate(:license_assignment, is_active: true)
      @inactive = Fabricate(:license_assignment, is_active: false)
    end

    it 'returns only active assignments' do
      assignments = described_class.find_active_assignments
      expect(assignments).to include(@active1, @active2)
      expect(assignments).not_to include(@inactive)
    end

    it 'respects additional criteria' do
      specific_license = @active1.license
      assignments = described_class.find_active_assignments(where: { license_id: specific_license.license_id })
      expect(assignments).to include(@active1)
      expect(assignments).not_to include(@active2)
    end
  end

  describe '.find_inactive_assignments' do
    before do
      LicenseAssignment.dataset.update(is_active: true)
      @inactive1 = Fabricate(:license_assignment, is_active: false)
      @inactive2 = Fabricate(:license_assignment, is_active: false)
      @active = Fabricate(:license_assignment, is_active: true)
    end

    it 'returns only inactive assignments' do
      assignments = described_class.find_inactive_assignments
      expect(assignments).to include(@inactive1, @inactive2)
      expect(assignments).not_to include(@active)
    end
  end

  describe '.activate' do
    let!(:inactive_assignment) { Fabricate(:license_assignment, is_active: false) }

    it 'activates the assignment' do
      assignment = described_class.activate(inactive_assignment.assignment_id)
      expect(assignment.is_active).to be true

      # Verify in database
      inactive_assignment.refresh
      expect(inactive_assignment.is_active).to be true
    end

    it 'logs the activation' do
      allow(described_class).to receive(:log_assignment_activated)
      assignment = described_class.activate(inactive_assignment.assignment_id)
      expect(described_class).to have_received(:log_assignment_activated).with(assignment)
    end

    it 'creates an assignment log entry' do
      expect do
        described_class.activate(inactive_assignment.assignment_id)
      end.to change(AssignmentLog, :count).by(1)

      log = AssignmentLog.last
      expect(log.action).to eq('ACTIVATED')
    end
  end

  describe '.deactivate' do
    let!(:active_assignment) { Fabricate(:license_assignment, is_active: true) }

    it 'deactivates the assignment' do
      assignment = described_class.deactivate(active_assignment.assignment_id)
      expect(assignment.is_active).to be false

      # Verify in database
      active_assignment.refresh
      expect(active_assignment.is_active).to be false
    end

    it 'logs the deactivation' do
      allow(described_class).to receive(:log_assignment_deactivated)
      assignment = described_class.deactivate(active_assignment.assignment_id)
      expect(described_class).to have_received(:log_assignment_deactivated).with(assignment)
    end

    it 'creates an assignment log entry' do
      expect do
        described_class.deactivate(active_assignment.assignment_id)
      end.to change(AssignmentLog, :count).by(1)

      log = AssignmentLog.last
      expect(log.action).to eq('DEACTIVATED')
    end
  end
end
