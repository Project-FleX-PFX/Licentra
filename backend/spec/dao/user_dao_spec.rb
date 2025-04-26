# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserDAO do
  let(:valid_attributes) do
    Fabricate.attributes_for(:user)
  end
  let!(:user1) { Fabricate(:user, username: 'testuser1', email: 'test1@example.com') }
  let!(:user2) { Fabricate(:user, username: 'testuser2', email: 'test2@example.com') }
  let!(:admin_role) { Fabricate(:role, role_name: 'Admin') }
  let!(:user_role) { Fabricate(:role, role_name: 'User') }

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new user' do
        expect do
          described_class.create(valid_attributes)
        end.to change(User, :count).by(1)
      end

      it 'returns the created user object', :aggregate_failures do
        user = described_class.create(valid_attributes)
        expect(user).to be_a(User)
        expect(user.username).to eq(valid_attributes[:username])
        expect(user.email).to eq(valid_attributes[:email])
        expect(user.pk).not_to be_nil
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_created)
        user = described_class.create(valid_attributes)
        expect(described_class).to have_received(:log_created).with(user)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { valid_attributes.merge(username: nil) }

      it 'does not create a new user' do
        expect do
          described_class.create(invalid_attributes)
        rescue StandardError
          # Expected error
        end.not_to change(User, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating user/i)
          expect(error.errors).to have_key(:username)
        end
      end
    end
  end

  describe '.find_by_username' do
    it 'returns the user when found' do
      user = described_class.find_by_username('testuser1')
      expect(user).to eq(user1)
    end

    it 'is case-insensitive' do
      user = described_class.find_by_username('TESTUSER1')
      expect(user).to eq(user1)
    end

    it 'returns nil when user not found' do
      expect(described_class.find_by_username('nonexistent')).to be_nil
    end

    it 'returns nil when username is nil or empty' do
      expect(described_class.find_by_username(nil)).to be_nil
      expect(described_class.find_by_username('')).to be_nil
    end

    it 'logs when user is found' do
      allow(described_class).to receive(:log_user_found_by_username)
      described_class.find_by_username('testuser1')
      expect(described_class).to have_received(:log_user_found_by_username).with('testuser1', user1)
    end
  end

  describe '.find_by_username!' do
    it 'returns the user when found' do
      user = described_class.find_by_username!('testuser1')
      expect(user).to eq(user1)
    end

    it 'raises RecordNotFound when user not found' do
      expect do
        described_class.find_by_username!('nonexistent')
      end.to raise_error(DAO::RecordNotFound)
    end
  end

  describe '.find_by_email' do
    it 'returns the user when found' do
      user = described_class.find_by_email('test1@example.com')
      expect(user).to eq(user1)
    end

    it 'is case-insensitive' do
      user = described_class.find_by_email('TEST1@EXAMPLE.COM')
      expect(user).to eq(user1)
    end

    it 'returns nil when email not found' do
      expect(described_class.find_by_email('nonexistent@example.com')).to be_nil
    end

    it 'returns nil when email is nil or empty' do
      expect(described_class.find_by_email(nil)).to be_nil
      expect(described_class.find_by_email('')).to be_nil
    end

    it 'logs when user is found' do
      allow(described_class).to receive(:log_user_found_by_email)
      described_class.find_by_email('test1@example.com')
      expect(described_class).to have_received(:log_user_found_by_email).with('test1@example.com', user1)
    end
  end

  describe '.find_by_email!' do
    it 'returns the user when found' do
      user = described_class.find_by_email!('test1@example.com')
      expect(user).to eq(user1)
    end

    it 'raises RecordNotFound when email not found' do
      expect do
        described_class.find_by_email!('nonexistent@example.com')
      end.to raise_error(DAO::RecordNotFound)
    end
  end

  describe '.find_active_users' do
    before do
      User.dataset.update(is_active: false)
      @active1 = Fabricate(:user, is_active: true)
      @active2 = Fabricate(:user, is_active: true)
      @inactive = Fabricate(:user, is_active: false)
    end

    it 'returns only active users' do
      users = described_class.find_active_users
      expect(users).to include(@active1, @active2)
      expect(users).not_to include(@inactive)
    end

    it 'respects additional criteria' do
      specific_username = @active1.username
      users = described_class.find_active_users(where: { username: specific_username })
      expect(users).to include(@active1)
      expect(users).not_to include(@active2)
    end
  end

  describe '.find_inactive_users' do
    before do
      User.dataset.update(is_active: true)
      @inactive1 = Fabricate(:user, is_active: false)
      @inactive2 = Fabricate(:user, is_active: false)
      @active = Fabricate(:user, is_active: true)
    end

    it 'returns only inactive users' do
      users = described_class.find_inactive_users
      expect(users).to include(@inactive1, @inactive2)
      expect(users).not_to include(@active)
    end
  end

  describe '.activate_user' do
    let!(:inactive_user) { Fabricate(:user, is_active: false) }

    it 'activates the user' do
      user = described_class.activate_user(inactive_user.user_id)
      expect(user.is_active).to be true

      # Verify in database
      inactive_user.refresh
      expect(inactive_user.is_active).to be true
    end

    it 'logs the activation' do
      allow(described_class).to receive(:log_user_activated)
      user = described_class.activate_user(inactive_user.user_id)
      expect(described_class).to have_received(:log_user_activated).with(user)
    end
  end

  describe '.deactivate_user' do
    let!(:active_user) { Fabricate(:user, is_active: true) }

    it 'deactivates the user' do
      user = described_class.deactivate_user(active_user.user_id)
      expect(user.is_active).to be false

      # Verify in database
      active_user.refresh
      expect(active_user.is_active).to be false
    end

    it 'logs the deactivation' do
      allow(described_class).to receive(:log_user_deactivated)
      user = described_class.deactivate_user(active_user.user_id)
      expect(described_class).to have_received(:log_user_deactivated).with(user)
    end
  end

  describe '.assign_role_by_name' do
    let!(:user) { Fabricate(:user) }

    it 'assigns the role to the user' do
      described_class.assign_role_by_name(user.user_id, 'Admin')

      # Verify role assignment
      user.refresh
      expect(user.roles.map(&:role_name)).to include('Admin')
    end

    it 'logs the role update' do
      allow(described_class).to receive(:log_user_roles_updated)
      described_class.assign_role_by_name(user.user_id, 'Admin')
      expect(described_class).to have_received(:log_user_roles_updated).with(user)
    end

    it 'raises RecordNotFound when user does not exist' do
      expect do
        described_class.assign_role_by_name(99_999, 'Admin')
      end.to raise_error(DAO::RecordNotFound)
    end

    it 'raises RecordNotFound when role does not exist' do
      expect do
        described_class.assign_role_by_name(user.user_id, 'NonexistentRole')
      end.to raise_error(DAO::RecordNotFound)
    end
  end

  describe '.remove_role_by_name' do
    let!(:user) { Fabricate(:user) }

    before do
      UserRoleDAO.create(user.user_id, admin_role.role_id)
    end

    it 'removes the role from the user' do
      described_class.remove_role_by_name(user.user_id, 'Admin')

      # Verify role removal
      user.refresh
      expect(user.roles.map(&:role_name)).not_to include('Admin')
    end

    it 'logs the role update' do
      allow(described_class).to receive(:log_user_roles_updated)
      described_class.remove_role_by_name(user.user_id, 'Admin')
      expect(described_class).to have_received(:log_user_roles_updated).with(user)
    end
  end

  describe '.set_roles_by_name' do
    let!(:user) { Fabricate(:user) }
    let!(:manager_role) { Fabricate(:role, role_name: 'Manager') }

    before do
      UserRoleDAO.create(user.user_id, admin_role.role_id)
    end

    it 'sets the exact roles specified' do
      described_class.set_roles_by_name(user.user_id, %w[User Manager])

      # Verify roles
      user.refresh
      role_names = user.roles.map(&:role_name)
      expect(role_names).to include('User', 'Manager')
      expect(role_names).not_to include('Admin')
      expect(role_names.count).to eq(2)
    end

    it 'logs the role update' do
      allow(described_class).to receive(:log_user_roles_updated)
      described_class.set_roles_by_name(user.user_id, ['User'])
      expect(described_class).to have_received(:log_user_roles_updated).with(user)
    end
  end

  describe '.delete' do
    let!(:user_to_delete) { Fabricate(:user) }

    before do
      UserRoleDAO.create(user_to_delete.user_id, user_role.role_id)
    end

    it 'removes the user and their role assignments' do
      expect do
        described_class.delete(user_to_delete.user_id)
      end.to change(User, :count).by(-1)

      # Verify role assignments are gone
      expect(UserRoleDAO.find_by_user(user_to_delete.user_id)).to be_empty
    end

    it 'logs the deletion' do
      allow(described_class).to receive(:log_deleted)
      described_class.delete(user_to_delete.user_id)
      expect(described_class).to have_received(:log_deleted).with(user_to_delete)
    end
  end
end
