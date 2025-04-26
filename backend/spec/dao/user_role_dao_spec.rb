# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserRoleDAO do
  let(:user) { Fabricate(:user) }
  let(:role) { Fabricate(:role) }

  describe '.create' do
    it 'creates a new user role assignment' do
      expect do
        described_class.create(user.user_id, role.role_id)
      end.to change(UserRole, :count).by(1)
    end

    it 'returns the created assignment object' do
      assignment = described_class.create(user.user_id, role.role_id)
      expect(assignment).to be_a(UserRole)
      expect(assignment.user_id).to eq(user.user_id)
      expect(assignment.role_id).to eq(role.role_id)
    end

    it 'logs the creation' do
      allow(described_class).to receive(:log_assignment_created)
      described_class.create(user.user_id, role.role_id)
      expect(described_class).to have_received(:log_assignment_created).with(user.user_id, role.role_id)
    end
  end

  describe '.find_by_user' do
    let!(:assignment) { described_class.create(user.user_id, role.role_id) }

    it 'returns assignments for the user' do
      assignments = described_class.find_by_user(user.user_id)
      expect(assignments).to include(assignment)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_user_fetched)
      described_class.find_by_user(user.user_id)
      expect(described_class).to have_received(:log_assignments_for_user_fetched).with(user.user_id, 1)
    end
  end

  describe '.find_by_role' do
    let!(:assignment) { described_class.create(user.user_id, role.role_id) }

    it 'returns assignments for the role' do
      assignments = described_class.find_by_role(role.role_id)
      expect(assignments).to include(assignment)
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_assignments_for_role_fetched)
      described_class.find_by_role(role.role_id)
      expect(described_class).to have_received(:log_assignments_for_role_fetched).with(role.role_id, 1)
    end
  end

  describe '.find_assignment' do
    let!(:assignment) { described_class.create(user.user_id, role.role_id) }

    it 'finds the specific assignment' do
      found = described_class.find_assignment(user.user_id, role.role_id)
      expect(found).to eq(assignment)
    end

    it 'returns nil if assignment does not exist' do
      expect(described_class.find_assignment(user.user_id, 999)).to be_nil
    end

    it 'logs the find operation when found' do
      allow(described_class).to receive(:log_assignment_found)
      described_class.find_assignment(user.user_id, role.role_id)
      expect(described_class).to have_received(:log_assignment_found).with(user.user_id, role.role_id)
    end

    it 'does not log when not found' do
      allow(described_class).to receive(:log_assignment_found)
      described_class.find_assignment(user.user_id, 999)
      expect(described_class).not_to have_received(:log_assignment_found)
    end
  end

  describe '.find_assignment!' do
    let!(:assignment) { described_class.create(user.user_id, role.role_id) }

    it 'finds the specific assignment' do
      found = described_class.find_assignment!(user.user_id, role.role_id)
      expect(found).to eq(assignment)
    end

    it 'raises error if assignment does not exist' do
      expect do
        described_class.find_assignment!(user.user_id, 999)
      end.to raise_error(DAO::RecordNotFound)
    end

    it 'logs the find operation' do
      allow(described_class).to receive(:log_assignment_found)
      described_class.find_assignment!(user.user_id, role.role_id)
      expect(described_class).to have_received(:log_assignment_found).with(user.user_id, role.role_id)
    end
  end

  describe '.exists?' do
    let!(:assignment) { described_class.create(user.user_id, role.role_id) }

    it 'returns true if assignment exists' do
      expect(described_class.exists?(user.user_id, role.role_id)).to be true
    end

    it 'returns false if assignment does not exist' do
      expect(described_class.exists?(user.user_id, 999)).to be false
    end
  end

  describe '.delete_assignment' do
    let!(:assignment) { described_class.create(user.user_id, role.role_id) }

    it 'deletes the assignment' do
      expect do
        described_class.delete_assignment(user.user_id, role.role_id)
      end.to change(UserRole, :count).by(-1)
    end

    it 'logs the deletion' do
      allow(described_class).to receive(:log_assignment_deleted)
      described_class.delete_assignment(user.user_id, role.role_id)
      expect(described_class).to have_received(:log_assignment_deleted).with(user.user_id, role.role_id)
    end

    it 'returns true if assignment was deleted' do
      expect(described_class.delete_assignment(user.user_id, role.role_id)).to be true
    end

    it 'returns false if assignment did not exist' do
      described_class.delete_assignment(user.user_id, role.role_id)
      expect(described_class.delete_assignment(user.user_id, role.role_id)).to be false
    end
  end

  describe '.delete_by_user' do
    let!(:assignment1) { described_class.create(user.user_id, role.role_id) }
    let!(:assignment2) { described_class.create(user.user_id, Fabricate(:role).role_id) }

    it 'deletes all assignments for the user' do
      expect do
        described_class.delete_by_user(user.user_id)
      end.to change(UserRole, :count).by(-2)
    end

    it 'logs the deletion' do
      allow(described_class).to receive(:log_assignments_deleted_for_user)
      described_class.delete_by_user(user.user_id)
      expect(described_class).to have_received(:log_assignments_deleted_for_user).with(user.user_id, 2)
    end

    it 'returns the number of deleted assignments' do
      expect(described_class.delete_by_user(user.user_id)).to eq(2)
    end
  end

  describe '.delete_by_role' do
    let!(:assignment1) { described_class.create(user.user_id, role.role_id) }
    let!(:assignment2) { described_class.create(Fabricate(:user).user_id, role.role_id) }

    it 'deletes all assignments for the role' do
      expect do
        described_class.delete_by_role(role.role_id)
      end.to change(UserRole, :count).by(-2)
    end

    it 'logs the deletion' do
      allow(described_class).to receive(:log_assignments_deleted_for_role)
      described_class.delete_by_role(role.role_id)
      expect(described_class).to have_received(:log_assignments_deleted_for_role).with(role.role_id, 2)
    end

    it 'returns the number of deleted assignments' do
      expect(described_class.delete_by_role(role.role_id)).to eq(2)
    end
  end
end
