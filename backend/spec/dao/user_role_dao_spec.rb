# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserRoleDAO do
  let(:user) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:role) { Fabricate(:role) }
  let(:admin_role) { Fabricate(:role, role_name: 'Admin') }

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

    describe 'Admin protection' do
      describe '.is_admin_role?' do
        it 'returns true for admin role' do
          expect(described_class.is_admin_role?(admin_role.role_id)).to be true
        end

        it 'returns false for non-admin role' do
          expect(described_class.is_admin_role?(role.role_id)).to be false
        end
      end

      describe '.is_user_admin?' do
        it 'returns true if user has admin role' do
          described_class.create(user.user_id, admin_role.role_id)
          expect(described_class.is_user_admin?(user.user_id)).to be true
        end

        it 'returns false if user does not have admin role' do
          fresh_user = Fabricate(:user) # Erzeuge einen komplett neuen User für diesen Test
          fresh_role = Fabricate(:role) # Erzeuge eine komplett neue Rolle für diesen Test
          described_class.create(fresh_user.user_id, fresh_role.role_id)
          expect(described_class.is_user_admin?(fresh_user.user_id)).to be false
        end
      end

      describe '.count_admins' do
        it 'returns the number of users with admin role' do
          expect(described_class.count_admins).to eq(0)

          described_class.create(user.user_id, admin_role.role_id)
          expect(described_class.count_admins).to eq(1)

          described_class.create(user2.user_id, admin_role.role_id)
          expect(described_class.count_admins).to eq(2)
        end
      end


      describe '.delete_assignment' do
        context 'when deleting admin role from last admin' do
          let!(:admin_user) { Fabricate(:user) }

          before do
            described_class.create(admin_user.user_id, admin_role.role_id)
          end

          it 'raises AdminProtectionError' do
            expect {
              described_class.delete_assignment(admin_user.user_id, admin_role.role_id)
            }.to raise_error(DAO::AdminProtectionError)
          end

          it 'logs the protection event' do
            allow(described_class).to receive(:log_admin_protection_deleting_admin_for_user)

            begin
              described_class.delete_assignment(admin_user.user_id, admin_role.role_id)
            rescue DAO::AdminProtectionError
              # Expected error
            end

            expect(described_class).to have_received(:log_admin_protection_deleting_admin_for_user).with(admin_user.user_id)
          end
        end

        context 'when multiple admins exist' do
          let!(:admin_user1) { Fabricate(:user) }
          let!(:admin_user2) { Fabricate(:user) }

          before do
            described_class.create(admin_user1.user_id, admin_role.role_id)
            described_class.create(admin_user2.user_id, admin_role.role_id)
          end

          it 'allows deleting admin role from one admin' do
            expect {
              described_class.delete_assignment(admin_user1.user_id, admin_role.role_id)
            }.to change(UserRole, :count).by(-1)
          end
        end
      end

      describe '.delete_by_user' do
        context 'when deleting all roles from last admin' do
          let!(:admin_user) { Fabricate(:user) }

          before do
            described_class.create(admin_user.user_id, admin_role.role_id)
            described_class.create(admin_user.user_id, role.role_id)
          end

          it 'raises AdminProtectionError' do
            expect {
              described_class.delete_by_user(admin_user.user_id)
            }.to raise_error(DAO::AdminProtectionError)
          end

          it 'logs the protection event' do
            allow(described_class).to receive(:log_admin_protection_deleting_assignments_for_user)

            begin
              described_class.delete_by_user(admin_user.user_id)
            rescue DAO::AdminProtectionError
              # Expected error
            end

            expect(described_class).to have_received(:log_admin_protection_deleting_assignments_for_user).with(admin_user.user_id)
          end
        end

        context 'when multiple admins exist' do
          let!(:admin_user1) { Fabricate(:user) }
          let!(:admin_user2) { Fabricate(:user) }

          before do
            described_class.create(admin_user1.user_id, admin_role.role_id)
            described_class.create(admin_user2.user_id, admin_role.role_id)
          end

          it 'allows deleting all roles from one admin' do
            expect {
              described_class.delete_by_user(admin_user1.user_id)
            }.to change(UserRole, :count).by(-1)
          end
        end
      end

      describe '.delete_by_role' do
        context 'when deleting admin role' do
          let!(:admin_user) { Fabricate(:user) }

          before do
            described_class.create(admin_user.user_id, admin_role.role_id)
          end

          it 'raises AdminProtectionError' do
            expect {
              described_class.delete_by_role(admin_role.role_id)
            }.to raise_error(DAO::AdminProtectionError)
          end

          it 'logs the protection event' do
            allow(described_class).to receive(:log_admin_protection_deleting_admin_role)

            begin
              described_class.delete_by_role(admin_role.role_id)
            rescue DAO::AdminProtectionError
              # Expected error
            end

            expect(described_class).to have_received(:log_admin_protection_deleting_admin_role)
          end
        end
      end
    end
  end
end
