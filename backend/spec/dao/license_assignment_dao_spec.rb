# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseAssignmentDAO do
  let!(:license) { Fabricate(:license) }
  let!(:user) { Fabricate(:user) }
  let!(:device) { Fabricate(:device) }

  let(:valid_user_assignment_attributes) do
    {
      license_id: license.license_id,
      user_id: user.user_id,
      device_id: nil,
      notes: 'Test user assignment'
    }
  end

  let(:valid_device_assignment_attributes) do
    {
      license_id: license.license_id,
      user_id: nil,
      device_id: device.device_id,
      notes: 'Test device assignment'
    }
  end

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
        expect(assignment.assignment_date).to be_a(Time)
      end
    end

    context 'with valid device assignment attributes' do
      it 'creates a new license assignment for a device' do
        assignment = described_class.create(valid_device_assignment_attributes)
        expect(assignment.device_id).to eq(device.device_id)
        expect(assignment.user_id).to be_nil
        expect(assignment.is_active).to be true
      end
    end

    context 'with invalid attributes (missing license_id)' do
      let(:invalid_attributes) { { license_id: license.license_id } }

      it 'does not create a new assignment' do
        expect do
          described_class.create(invalid_attributes)
        rescue DAO::ValidationError
        end.not_to change(LicenseAssignment, :count)
      end

      it 'raises a ValidationError or specific Sequel Error', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating license assignment/i)
          expect(error.errors).to include(:base)
          expect(error.errors[:base]).to include('Either user_id or device_id must be set')
        end
      end
    end
  end

  describe '.find_by_license' do
    let!(:specific_license) { Fabricate(:license) }
    let!(:assignment1) { Fabricate(:user_license_assignment, license: specific_license) }
    let!(:assignment2) { Fabricate(:device_license_assignment, license: specific_license) }
    let!(:other_user_assignment_on_diff_license) { Fabricate(:user_license_assignment) }

    it 'returns assignments only for the specified license' do
      assignments = described_class.find_by_license(specific_license.license_id)
      expect(assignments.map(&:assignment_id)).to match_array([assignment1.assignment_id, assignment2.assignment_id])
      expect(assignments.map(&:assignment_id)).not_to include(other_user_assignment_on_diff_license.assignment_id)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_license_fetched)
      described_class.find_by_license(specific_license.license_id)
      expect(described_class).to have_received(:log_assignments_for_license_fetched).with(specific_license.license_id,
                                                                                          2)
    end
  end

  describe '.find_by_user' do
    let!(:specific_user) { Fabricate(:user) }
    let!(:user_assignment1) { Fabricate(:user_license_assignment, user: specific_user) }
    let!(:user_assignment2) { Fabricate(:user_license_assignment, user: specific_user) }
    let!(:some_device_assignment) { Fabricate(:device_license_assignment) }

    it 'returns assignments only for the specified user' do
      assignments = described_class.find_by_user(specific_user.user_id)
      expect(assignments.map(&:assignment_id)).to match_array([user_assignment1.assignment_id,
                                                               user_assignment2.assignment_id])
      expect(assignments.map(&:assignment_id)).not_to include(some_device_assignment.assignment_id)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_user_fetched)
      described_class.find_by_user(specific_user.user_id)
      expect(described_class).to have_received(:log_assignments_for_user_fetched).with(specific_user.user_id, 2)
    end
  end

  describe '.find_by_device' do
    let!(:specific_device) { Fabricate(:device) }
    let!(:device_assignment1) { Fabricate(:device_license_assignment, device: specific_device) }
    let!(:device_assignment2) { Fabricate(:device_license_assignment, device: specific_device) }
    let!(:some_user_assignment) { Fabricate(:user_license_assignment) }

    it 'returns assignments only for the specified device' do
      assignments = described_class.find_by_device(specific_device.device_id)
      expect(assignments.map(&:assignment_id)).to match_array([device_assignment1.assignment_id,
                                                               device_assignment2.assignment_id])
      expect(assignments.map(&:assignment_id)).not_to include(some_user_assignment.assignment_id)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_device_fetched)
      described_class.find_by_device(specific_device.device_id)
      expect(described_class).to have_received(:log_assignments_for_device_fetched).with(specific_device.device_id, 2)
    end
  end

  describe '.find_active_assignments' do
    let!(:active1) { Fabricate(:license_assignment, is_active: true) }
    let!(:active2) { Fabricate(:license_assignment, is_active: true) }
    let!(:inactive1) { Fabricate(:license_assignment, is_active: false) }

    before(:all) do
      LicenseAssignment.dataset.delete
    end

    it 'returns only active assignments' do
      assignments = described_class.find_active_assignments
      expect(assignments.map(&:assignment_id)).to match_array([active1.assignment_id, active2.assignment_id])
      expect(assignments.map(&:assignment_id)).not_to include(inactive1.assignment_id)
    end

    it 'respects additional criteria' do
      specific_license_id = active1.license_id
      assignments = described_class.find_active_assignments(where: { license_id: specific_license_id })
      expect(assignments.map(&:assignment_id)).to eq([active1.assignment_id])
    end
  end

  describe '.find_inactive_assignments' do
    let!(:active1) { Fabricate(:license_assignment, is_active: true) }
    let!(:inactive1) { Fabricate(:license_assignment, is_active: false) }
    let!(:inactive2) { Fabricate(:license_assignment, is_active: false) }

    before(:all) do
      LicenseAssignment.dataset.delete
    end

    it 'returns only inactive assignments' do
      assignments = described_class.find_inactive_assignments
      expect(assignments.map(&:assignment_id)).to match_array([inactive1.assignment_id, inactive2.assignment_id])
      expect(assignments.map(&:assignment_id)).not_to include(active1.assignment_id)
    end
  end

  describe '.activate' do
    let!(:inactive_assignment) { Fabricate(:license_assignment, is_active: false) }
    let(:assignment_id) { inactive_assignment.assignment_id }

    it 'activates the assignment (sets is_active to true)' do
      expect(inactive_assignment.reload.is_active).to be false

      updated_assignment = described_class.activate(assignment_id)
      expect(updated_assignment.is_active).to be true

      expect(inactive_assignment.reload.is_active).to be true
    end

    it 'logs the activation action within the DAO' do
      allow(described_class).to receive(:log_assignment_activated)
      updated_assignment = described_class.activate(assignment_id)
      expect(described_class).to have_received(:log_assignment_activated).with(updated_assignment)
    end
  end

  describe '.deactivate' do
    let!(:active_assignment) { Fabricate(:license_assignment, is_active: true) }
    let(:assignment_id) { active_assignment.assignment_id }

    it 'deactivates the assignment (sets is_active to false)' do
      expect(active_assignment.reload.is_active).to be true

      updated_assignment = described_class.deactivate(assignment_id)
      expect(updated_assignment.is_active).to be false

      expect(active_assignment.reload.is_active).to be false
    end

    it 'logs the deactivation action within the DAO' do
      allow(described_class).to receive(:log_assignment_deactivated)
      updated_assignment = described_class.deactivate(assignment_id)
      expect(described_class).to have_received(:log_assignment_deactivated).with(updated_assignment)
    end
  end

  describe '.find_active_for_user_with_details' do
    let!(:user_x) { Fabricate(:user) }
    let!(:product_x) { Fabricate(:product, product_name: 'Product X') }
    let!(:license_x) { Fabricate(:license, product: product_x) }
    let!(:assignment_x_active) { Fabricate(:license_assignment, user: user_x, license: license_x, is_active: true) }
    let!(:assignment_x_inactive) { Fabricate(:license_assignment, user: user_x, license: license_x, is_active: false) }
    let!(:assignment_y_active) do
      Fabricate(:license_assignment, user: Fabricate(:user), license: license_x, is_active: true)
    end
    it 'returns only active assignments for the specified user' do
      assignments = described_class.find_active_for_user_with_details(user_x.user_id)
      expect(assignments.count).to eq(1)
      expect(assignments.first.assignment_id).to eq(assignment_x_active.assignment_id)
    end

    it 'eager loads the license and product details' do
      assignments = described_class.find_active_for_user_with_details(user_x.user_id)
      expect(assignments.first.associations).to have_key(:license)
      expect(assignments.first.license).to be_a(License)
      expect(assignments.first.license.associations).to have_key(:product)
      expect(assignments.first.license.product).to be_a(Product)
      expect(assignments.first.license.product.product_name).to eq('Product X')
    end

    it 'returns an empty array if user has no active assignments' do
      user_z = Fabricate(:user)
      assignments = described_class.find_active_for_user_with_details(user_z.user_id)
      expect(assignments).to be_empty
    end
  end
end
