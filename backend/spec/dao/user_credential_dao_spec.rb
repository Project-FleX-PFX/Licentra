# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserCredentialDAO do
  let(:user) { Fabricate(:user) }
  let!(:credential) { Fabricate(:user_credential, user: user) }

  describe '.update' do
    it 'raises NotImplementedError' do
      expect do
        described_class.update(user.user_id, password: 'newpa$$worD1!')
      end.to raise_error(NotImplementedError, /use update_password/i)
    end
  end

  describe '.update_password' do
    context 'with valid new password' do
      it 'updates the password hash' do
        old_hash = credential.password_hash
        new_password = 'new_secure_pass#worD123!'

        updated_credential = described_class.update_password(user.user_id, new_password)

        expect(updated_credential).to be_a(UserCredential)
        expect(updated_credential.password_hash).not_to eq(old_hash)
        # Verify that the new password matches the hash
        expect(BCrypt::Password.new(updated_credential.password_hash)).to eq(new_password)
      end

      it 'logs the password update' do
        allow(described_class).to receive(:log_password_updated)
        described_class.update_password(user.user_id, 'new_secure_pass#worD123!')
        expect(described_class).to have_received(:log_password_updated).with(an_instance_of(UserCredential))
      end
    end

    context 'with invalid password input' do
      it 'raises a validation error for empty password' do
        expect do
          described_class.update_password(user.user_id, '')
        end.to raise_error(DAO::ValidationError)
      end

      it 'raises a validation error for nil password' do
        expect do
          described_class.update_password(user.user_id, nil)
        end.to raise_error(DAO::ValidationError)
      end
    end

    context 'when user credential not found' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.update_password(999_999, 'valid_password')
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.find!' do
    it 'returns the credential when found' do
      found_credential = described_class.find!(user.user_id)
      expect(found_credential).to eq(credential)
    end

    it 'raises RecordNotFound when credential not found' do
      expect do
        described_class.find!(999_999)
      end.to raise_error(DAO::RecordNotFound)
    end
  end

  describe '.create' do
    let(:new_user) { Fabricate(:user) }
    let(:valid_attributes) do
      {
        user_id: new_user.user_id,
        password_hash: BCrypt::Password.create(DEFAULT_PASSWORD)
      }
    end

    it 'creates a new credential' do
      expect do
        described_class.create(valid_attributes)
      end.to change(UserCredential, :count).by(1)
    end

    it 'returns the created credential' do
      credential = described_class.create(valid_attributes)
      expect(credential).to be_a(UserCredential)
      expect(credential.user_id).to eq(new_user.user_id)
    end

    it 'logs the creation' do
      allow(described_class).to receive(:log_created)
      credential = described_class.create(valid_attributes)
      expect(described_class).to have_received(:log_created).with(credential)
    end
  end
end
