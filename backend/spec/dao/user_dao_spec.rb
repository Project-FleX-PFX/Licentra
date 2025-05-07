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

  # Tests for locking users
  describe '.increment_failed_attempts' do
    let!(:user) { Fabricate(:user, failed_login_attempts: 1) }

    context 'when the user exists' do
      it 'increments the failed_login_attempts counter by 1' do
        UserDAO.increment_failed_attempts(user)
        expect(user.reload.failed_login_attempts).to eq(2)
      end

      it 'logs the increment event' do
        expect(UserDAO).to receive(:log_info).with("Incremented failed attempts for user #{user.email}. New count: 2")
        UserDAO.increment_failed_attempts(user)
      end

      it 'returns the updated user instance' do
        updated_user = UserDAO.increment_failed_attempts(user)
        expect(updated_user).to be_a(User)
        expect(updated_user.pk).to eq(user.pk)
        expect(updated_user.failed_login_attempts).to eq(2)
      end
    end

    context 'when the user is nil' do
      it 'returns nil and does not attempt to log' do
        expect(UserDAO).not_to receive(:log_info)
        expect(UserDAO).not_to receive(:log_error)
        expect(UserDAO.increment_failed_attempts(nil)).to be_nil
      end
    end

    context 'when the database update fails (simulated)' do
      before do
        allow(UserDAO.model_class).to receive_message_chain(:where, :update).and_return(0)
      end

      it 'logs an error' do
        expect(UserDAO).to receive(:log_error).with("Failed to increment failed login attempts for user ID #{user.pk}. No rows updated.")
        UserDAO.increment_failed_attempts(user)
      end

      it 'returns nil' do
        expect(UserDAO.increment_failed_attempts(user)).to be_nil
      end

      it 'does not change the original user instance attributes in memory (before reload)' do
        original_attempts = user.failed_login_attempts
        UserDAO.increment_failed_attempts(user)
        expect(user.failed_login_attempts).to eq(original_attempts)
      end
    end
  end

  describe '.lock_user' do
    let!(:user) { Fabricate(:user, locked_at: nil) }

    context 'when the user exists' do
      it 'sets the locked_at timestamp to the current time' do
        time_before_lock = Time.now
        UserDAO.lock_user(user)
        time_after_lock = Time.now

        locked_time = user.reload.locked_at
        expect(locked_time).to be_a(Time)
        expect(locked_time).to be >= time_before_lock
        expect(locked_time).to be <= time_after_lock
      end

      it 'logs the lock event' do
        expect(UserDAO).to receive(:log_info).with("Locked account for user #{user.email}")
        UserDAO.lock_user(user)
      end

      it 'returns the updated user instance' do
        updated_user = UserDAO.lock_user(user)
        expect(updated_user).to be_a(User)
        expect(updated_user.pk).to eq(user.pk)
        expect(updated_user.locked_at).not_to be_nil
      end
    end

    context 'when the user is nil' do
      it 'returns nil and does not attempt to log' do
        expect(UserDAO).not_to receive(:log_info)
        expect(UserDAO).not_to receive(:log_error)
        expect(UserDAO.lock_user(nil)).to be_nil
      end
    end

    context 'when the database update fails (simulated)' do
      before do
        allow(UserDAO.model_class).to receive_message_chain(:where, :update).and_return(0)
      end

      it 'logs an error' do
        expect(UserDAO).to receive(:log_error).with("Failed to lock account for user ID #{user.pk}. No rows updated.")
        UserDAO.lock_user(user)
      end

      it 'returns nil' do
        expect(UserDAO.lock_user(user)).to be_nil
      end
    end
  end

  describe '.reset_lockout' do
    let!(:locked_user) { Fabricate(:user, failed_login_attempts: 3, locked_at: Time.now) }
    let!(:unlocked_user) { Fabricate(:user, failed_login_attempts: 0, locked_at: nil) }

    context 'when the user exists and is locked out' do
      it 'resets failed_login_attempts to 0' do
        UserDAO.reset_lockout(locked_user)
        expect(locked_user.reload.failed_login_attempts).to eq(0)
      end

      it 'clears the locked_at timestamp (sets to nil)' do
        UserDAO.reset_lockout(locked_user)
        expect(locked_user.reload.locked_at).to be_nil
      end

      it 'logs the reset event' do
        expect(UserDAO).to receive(:log_info).with("Reset lockout status for user #{locked_user.email}")
        UserDAO.reset_lockout(locked_user)
      end

      it 'returns the updated user instance' do
        updated_user = UserDAO.reset_lockout(locked_user)
        expect(updated_user).to be_a(User)
        expect(updated_user.pk).to eq(locked_user.pk)
        expect(updated_user.failed_login_attempts).to eq(0)
        expect(updated_user.locked_at).to be_nil
      end
    end

    context 'when the user is not locked out (no action needed)' do
      it 'returns the user instance without modification' do
        expect(UserDAO.model_class).not_to receive(:where)

        original_user_attributes = unlocked_user.values.dup

        returned_user = UserDAO.reset_lockout(unlocked_user)

        expect(returned_user).to eq(unlocked_user)
        expect(unlocked_user.values).to eq(original_user_attributes)
      end

      it 'does not log an event' do
        expect(UserDAO).not_to receive(:log_info)
        UserDAO.reset_lockout(unlocked_user)
      end
    end

    context 'when the user is nil' do
      it 'returns nil and does not attempt to log' do
        expect(UserDAO).not_to receive(:log_info)
        expect(UserDAO).not_to receive(:log_error)
        expect(UserDAO.reset_lockout(nil)).to be_nil
      end
    end

    context 'when the database update fails for a locked user (simulated)' do
      before do
        allow(locked_user).to receive(:failed_login_attempts).and_return(3)
        allow(locked_user).to receive(:locked_at).and_return(Time.now)
        allow(UserDAO.model_class).to receive_message_chain(:where, :update).and_return(0)
      end

      it 'logs an error' do
        expect(UserDAO).to receive(:log_error).with("Failed to reset lockout status for user ID #{locked_user.pk}. No rows updated.")
        UserDAO.reset_lockout(locked_user)
      end

      it 'returns nil' do
        expect(UserDAO.reset_lockout(locked_user)).to be_nil
      end
    end
  end

  describe '._perform_atomic_user_update' do
    let!(:user) { Fabricate(:user, email: 'privatetest@example.com', failed_login_attempts: 1) }
    let(:update_payload) do
      { failed_login_attempts: Sequel.+(:failed_login_attempts, 2), email: 'newprivate@example.com' }
    end
    let(:action_description) { 'perform a test update' }
    let(:context_string) do
      "#{action_description.capitalize} for user ID #{user.pk}"
    end

    context 'when update fails (0 rows updated)' do
      before do
        allow(UserDAO.model_class).to receive_message_chain(:where, :update).and_return(0)
      end

      it 'logs an error' do
        expect(UserDAO).to receive(:log_error).with("Failed to #{action_description.downcase} for user ID #{user.pk}. No rows updated.")
        UserDAO.send(:_perform_atomic_user_update, user, update_payload, action_description)
      end

      it 'returns nil' do
        expect(UserDAO.send(:_perform_atomic_user_update, user, update_payload, action_description)).to be_nil
      end
    end

    context 'when a Sequel::DatabaseError occurs during update' do
      let(:db_error_message) { 'Connection timeout' }
      before do
        allow(UserDAO.model_class).to receive_message_chain(:where, :update).and_raise(
          Sequel::DatabaseError.new(db_error_message)
        )
        allow(DaoLogger).to receive(:log_error)
      end
    end

    context 'when a generic StandardError occurs during update' do
      let(:generic_error_message) { 'Something unexpected happened' }
      let(:generic_error) { StandardError.new(generic_error_message) }
      before do
        allow(UserDAO.model_class).to receive_message_chain(:where, :update).and_raise(generic_error)
        allow(DaoLogger).to receive(:log_error)
      end

      it 'logs the unknown error via DaoLogger' do
        expect(DaoLogger).to receive(:log_error).with("Unknown error while #{context_string}: #{generic_error_message}")
        expect do
          UserDAO.send(:_perform_atomic_user_update, user, update_payload, action_description)
        end.to raise_error(generic_error)
      end
    end
  end
end
