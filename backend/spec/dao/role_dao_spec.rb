# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RoleDAO do
  let(:valid_attributes) do
    Fabricate.attributes_for(:role)
  end
  let!(:admin_role) { Fabricate(:role, role_name: 'Admin') }
  let!(:user_role) { Fabricate(:role, role_name: 'User') }

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new role' do
        expect do
          described_class.create(valid_attributes)
        end.to change(Role, :count).by(1)
      end

      it 'returns the created role object', :aggregate_failures do
        role = described_class.create(valid_attributes)
        expect(role).to be_a(Role)
        expect(role.role_name).to eq(valid_attributes[:role_name])
        expect(role.pk).not_to be_nil
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_created)
        role = described_class.create(valid_attributes)
        expect(described_class).to have_received(:log_created).with(role)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { role_name: nil } }

      it 'does not create a new role' do
        expect do
          described_class.create(invalid_attributes)
        rescue StandardError
          # Expected error
        end.not_to change(Role, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating role/i)
          expect(error.errors).to have_key(:role_name)
        end
      end
    end
  end

  describe '.find_by_name' do
    it 'returns the role when found' do
      role = described_class.find_by_name('Admin')
      expect(role).to eq(admin_role)
    end

    it 'returns nil when role not found' do
      expect(described_class.find_by_name('Nonexistent Role')).to be_nil
    end

    it 'returns nil when name is nil or empty' do
      expect(described_class.find_by_name(nil)).to be_nil
      expect(described_class.find_by_name('')).to be_nil
    end

    it 'logs when role is found' do
      allow(described_class).to receive(:log_role_found_by_name)
      described_class.find_by_name('Admin')
      expect(described_class).to have_received(:log_role_found_by_name).with('Admin', admin_role)
    end

    it 'does not log when role is not found' do
      allow(described_class).to receive(:log_role_found_by_name)
      described_class.find_by_name('Nonexistent Role')
      expect(described_class).not_to have_received(:log_role_found_by_name)
    end
  end

  describe '.find_by_name!' do
    it 'returns the role when found' do
      role = described_class.find_by_name!('Admin')
      expect(role).to eq(admin_role)
    end

    it 'raises RecordNotFound when role not found' do
      expect do
        described_class.find_by_name!('Nonexistent Role')
      end.to raise_error(DAO::RecordNotFound)
    end
  end

  describe '.delete' do
    context 'when role has no user assignments' do
      let!(:role_to_delete) { Fabricate(:role, role_name: 'DeleteMe') }

      it 'removes the role from the database' do
        expect do
          described_class.delete(role_to_delete.pk)
        end.to change(Role, :count).by(-1)
        expect(Role[role_to_delete.pk]).to be_nil
      end

      it 'returns true' do
        expect(described_class.delete(role_to_delete.pk)).to be true
      end

      it 'logs the deletion' do
        allow(described_class).to receive(:log_deleted)
        described_class.delete(role_to_delete.pk)
        expect(described_class).to have_received(:log_deleted).with(role_to_delete)
      end
    end

    context 'when role has user assignments' do
      let!(:role_with_users) { Fabricate(:role, role_name: 'RoleWithUsers') }
      let!(:user) { Fabricate(:user) }

      before do
        UserRoleDAO.create(user.user_id, role_with_users.role_id)
      end

      it 'does not delete the role' do
        expect do
          described_class.delete(role_with_users.pk)
        rescue StandardError
          # Expected error
        end.not_to change(Role, :count)
      end

      it 'raises a DatabaseError' do
        expect do
          described_class.delete(role_with_users.pk)
        end.to raise_error(DAO::DatabaseError, /still assigned to users/i)
      end
    end

    context 'when role does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.delete(99_999)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end
end
