# frozen_string_literal: true

require 'spec_helper'
require 'time'

RSpec.describe SecurityLogDAO do
  let!(:user1_sl) { Fabricate(:user, username: 'User1ForSecLog', email: 'user1sl@example.com') }
  let!(:user2_sl) { Fabricate(:user, username: 'User2ForSecLog', email: 'user2sl@example.com') }
  let!(:admin_user_sl) do
    Fabricate(:user, username: 'AdminForSecLog', email: 'adminsl@example.com')
  end
  let(:test_unknown_user) { described_class.send(:_unknown_user_for_logging) }
  let(:test_system_user) { described_class.send(:_system_user_for_logging) }

  let!(:product_sl) { Fabricate(:product, product_name: 'Secure Product') }
  let!(:license_sl) { Fabricate(:license, product: product_sl, license_name: 'Secure License Key') }

  ONE_MINUTE = 60
  ONE_HOUR = ONE_MINUTE * 60
  ONE_DAY = ONE_HOUR * 24

  before(:each) do
    SecurityLog.dataset.delete
  end

  shared_examples 'a security log creation method' do |log_method_name, action_constant, expected_object_type|
    it "creates a new security log for #{action_constant}" do
      expect do
        described_class.public_send(log_method_name, **params_hash)
      end.to change(SecurityLog, :count).by(1)
    end

    it "returns the created log with correct denormalized data and details for #{action_constant}",
       :aggregate_failures do
      log = described_class.public_send(log_method_name, **params_hash)

      expect(log).to be_a(SecurityLog)
      expect(log.pk).not_to be_nil
      expect(log.action).to eq(action_constant)
      expect(log.object).to eq(expected_object_type)
      expect(log.log_timestamp.to_i).to be_within(2).of(Time.now.to_i)

      expected_denormalized_user = if log_method_name == :log_login_failure
                                     test_unknown_user
                                   else
                                     params_hash[:acting_user] || params_hash[:user_making_request] || params_hash[:user_who_changed_password] || params_hash[:user]
                                   end
      expected_denormalized_user ||= test_system_user

      expect(log.user_id).to eq(expected_denormalized_user.user_id)
      expect(log.username).to eq(expected_denormalized_user.username)
      expect(log.email).to eq(expected_denormalized_user.email)

      expect(log.details).to be_a(String)
      expect(log.details).not_to be_empty
    end
  end

  describe '.log_login_success' do
    let(:params_hash) { { user: user1_sl } }
    it_behaves_like 'a security log creation method',
                    :log_login_success, SecurityLogDAO::Actions::LOGIN_SUCCESS, 'UserSession'
    it 'contains correct details' do
      log = described_class.log_login_success(**params_hash)
      expect(log.details).to eq("User '#{user1_sl.username}' (ID: #{user1_sl.user_id}) successfully logged in.")
    end
  end

  describe '.log_login_failure' do
    let(:params_hash) { { attempted_username: 'failed_user', ip_address: '1.2.3.4' } }
    it_behaves_like 'a security log creation method',
                    :log_login_failure, SecurityLogDAO::Actions::LOGIN_FAILURE, 'UserSession'
    it 'contains correct details and uses UNKNOWN_USER' do
      log = described_class.log_login_failure(**params_hash)
      expect(log.details).to eq("Failed login attempt for username 'failed_user'. IP: 1.2.3.4.")
      expect(log.user_id).to eq(test_unknown_user.user_id)
    end
  end

  describe '.log_password_reset_request' do
    let(:params_hash) { { user_making_request: user1_sl, target_email: 'reset@example.com' } }
    it_behaves_like 'a security log creation method',
                    :log_password_reset_request, SecurityLogDAO::Actions::PASSWORD_RESET_REQUEST, 'UserAccount'
  end

  describe '.log_password_changed' do
    let(:params_hash) { { user_who_changed_password: user1_sl } }
    it_behaves_like 'a security log creation method',
                    :log_password_changed, SecurityLogDAO::Actions::PASSWORD_CHANGED, 'UserAccount'
  end

  describe '.log_user_created' do
    let(:params_hash) { { acting_user: admin_user_sl, created_user: user2_sl } }
    it_behaves_like 'a security log creation method',
                    :log_user_created, SecurityLogDAO::Actions::USER_CREATED, 'UserAccount'
  end

  describe '.log_user_updated' do
    let(:params_hash) { { acting_user: admin_user_sl, updated_user: user1_sl, changes_description: 'role changed' } }
    it_behaves_like 'a security log creation method',
                    :log_user_updated, SecurityLogDAO::Actions::USER_UPDATED, 'UserAccount'
  end

  describe '.log_user_deleted' do
    let(:params_hash) { { acting_user: admin_user_sl, deleted_user_username: 'OldUser', deleted_user_id: 999 } }
    it_behaves_like 'a security log creation method',
                    :log_user_deleted, SecurityLogDAO::Actions::USER_DELETED, 'UserAccount'
  end

  describe '.log_product_created' do
    let(:params_hash) { { acting_user: admin_user_sl, product: product_sl } }
    it_behaves_like 'a security log creation method',
                    :log_product_created, SecurityLogDAO::Actions::PRODUCT_CREATED, 'Product'
  end

  describe '.log_product_updated' do
    let(:params_hash) { { acting_user: admin_user_sl, product: product_sl, changes_description: 'price updated' } }
    it_behaves_like 'a security log creation method',
                    :log_product_updated, SecurityLogDAO::Actions::PRODUCT_UPDATED, 'Product'
  end

  describe '.log_product_deleted' do
    let(:params_hash) { { acting_user: admin_user_sl, deleted_product_name: 'OldProduct', deleted_product_id: 888 } }
    it_behaves_like 'a security log creation method',
                    :log_product_deleted, SecurityLogDAO::Actions::PRODUCT_DELETED, 'Product'
  end

  describe '.log_license_created' do
    let(:params_hash) { { acting_user: admin_user_sl, license: license_sl } }
    it_behaves_like 'a security log creation method',
                    :log_license_created, SecurityLogDAO::Actions::LICENSE_CREATED, 'License'
  end

  describe '.log_license_updated' do
    let(:params_hash) { { acting_user: admin_user_sl, license: license_sl, changes_description: 'seats changed' } }
    it_behaves_like 'a security log creation method',
                    :log_license_updated, SecurityLogDAO::Actions::LICENSE_UPDATED, 'License'
  end

  describe '.log_license_deleted' do
    let(:params_hash) { { acting_user: admin_user_sl, deleted_license_name: 'OldLicense', deleted_license_id: 777 } }
    it_behaves_like 'a security log creation method',
                    :log_license_deleted, SecurityLogDAO::Actions::LICENSE_DELETED, 'License'
  end

  describe 'operations on individual logs' do
    let!(:log_ind_1) { Fabricate(:security_log, source_user: user1_sl, action: 'IND_ACTION_A') }
    let!(:log_ind_2) { Fabricate(:security_log, source_user: user2_sl, action: 'IND_ACTION_B') }

    describe '.find!' do
      context 'when the log exists' do
        it 'returns the log object' do
          expect(described_class.find!(log_ind_1.pk)).to eq(log_ind_1)
        end
      end
      context 'when the log does not exist' do
        it 'raises an error' do
          non_existent_id = (SecurityLog.max(:log_id) || 0) + 1
          expect { described_class.find!(non_existent_id) }.to raise_error(DAO::RecordNotFound)
        end
      end
    end

    describe '.find' do
      it 'returns the log object if it exists' do
        expect(described_class.find(log_ind_1.pk)).to eq(log_ind_1)
      end
      it 'returns nil if the log does not exist' do
        non_existent_id = (SecurityLog.max(:log_id) || 0) + 1
        expect(described_class.find(non_existent_id)).to be_nil
      end
    end
  end

  describe '.all' do
    let!(:time_all) { Time.now.utc }
    let!(:log_c_all) { Fabricate(:security_log, source_user: user1_sl, log_timestamp: time_all, action: 'C_ALL') }
    let!(:log_b_all) do
      Fabricate(:security_log, source_user: user2_sl, log_timestamp: time_all - (5 * ONE_MINUTE), action: 'B_ALL')
    end
    let!(:log_a_all) do
      Fabricate(:security_log, source_user: user1_sl, log_timestamp: time_all - (10 * ONE_MINUTE), action: 'A_ALL')
    end

    it 'returns all logs, ordered by timestamp desc, then id desc', :aggregate_failures do
      logs = described_class.all
      expect(logs.count).to eq(3)
      expect(logs.map(&:pk)).to eq([log_c_all.pk, log_b_all.pk, log_a_all.pk])
    end
  end

  describe '.where' do
    let!(:log_w1) { Fabricate(:security_log, source_user: user1_sl, action: 'TARGET_W', object: 'ObjW1') }
    let!(:log_w2) { Fabricate(:security_log, source_user: user2_sl, action: 'OTHER_W', object: 'ObjW2') }
    let!(:log_w3) { Fabricate(:security_log, source_user: user1_sl, action: 'TARGET_W', object: 'ObjW3') }

    it 'filters by a single criterion' do
      expect(described_class.where(action: 'TARGET_W').map(&:pk)).to match_array([log_w1.pk, log_w3.pk])
    end
    it 'filters by multiple criteria' do
      expect(described_class.where(action: 'TARGET_W', object: 'ObjW1').map(&:pk)).to eq([log_w1.pk])
    end
  end

  describe '.find_by_user' do
    let!(:log_fbu_u1_b) { Fabricate(:security_log, source_user: user1_sl, log_timestamp: Time.now, action: 'FBU1B') }
    let!(:log_fbu_u1_a) do
      Fabricate(:security_log, source_user: user1_sl, log_timestamp: Time.now - (10 * ONE_MINUTE), action: 'FBU1A')
    end
    let!(:log_fbu_u2) { Fabricate(:security_log, source_user: user2_sl, action: 'FBU2') }

    it 'returns logs for the specified user, ordered desc by timestamp' do
      logs = described_class.find_by_user(user1_sl.user_id)
      expect(logs.map(&:pk)).to eq([log_fbu_u1_b.pk, log_fbu_u1_a.pk])
      expect(logs.count).to eq(2)
    end
  end

  describe '.find_with_details' do
    let!(:time_fwd_now) { Time.now.utc.round }
    let!(:time_fwd_yest) { (time_fwd_now - ONE_DAY).round }
    let!(:time_fwd_yest_plus_sec) { (time_fwd_now - ONE_DAY + 1).round }
    let!(:time_fwd_two_days) { (time_fwd_now - (2 * ONE_DAY)).round }

    let!(:fwd_log_u1_now) do
      Fabricate(:security_log, source_user: user1_sl, action: 'ACTION_U1_NOW', object: 'ObjectA',
                               details: 'User1 did something now', log_timestamp: time_fwd_now)
    end
    let!(:fwd_log_u1_yest_plus) do
      Fabricate(:security_log, source_user: user1_sl, action: 'ACTION_U1_YEST_PLUS', object: 'ObjectA',
                               details: 'User1 did something yesterday plus', log_timestamp: time_fwd_yest_plus_sec)
    end
    let!(:fwd_log_u2_yest) do
      Fabricate(:security_log, source_user: user2_sl, action: 'ACTION_U2_YEST', object: 'ObjectB',
                               details: 'User2 did something yesterday', log_timestamp: time_fwd_yest)
    end
    let!(:fwd_log_unknown_ancient) do
      Fabricate(:security_log, source_user: test_unknown_user, action: 'ACTION_UNKNOWN_ANCIENT',
                               object: 'ObjectC', details: 'Unknown user event ancient', log_timestamp: time_fwd_two_days)
    end

    let(:all_fwd_logs_ordered_pks) do
      [fwd_log_u1_now.pk, fwd_log_u1_yest_plus.pk, fwd_log_u2_yest.pk, fwd_log_unknown_ancient.pk]
    end

    context 'without filters' do
      it 'returns all logs paginated, ordered by timestamp desc then id desc', :aggregate_failures do
        result = described_class.find_with_details({}, { per_page: 2 })
        expect(result[:logs].count).to eq(2)
        expect(result[:logs].map(&:pk)).to eq(all_fwd_logs_ordered_pks.slice(0, 2))
        expect(result[:logs][0].username).to eq(user1_sl.username)
        expect(result[:total_entries]).to eq(4)
        expect(result[:total_pages]).to eq(2)
        expect(result[:current_page]).to eq(1)
      end
      it 'fetches the second page correctly' do
        result = described_class.find_with_details({}, { page: 2, per_page: 2 })
        expect(result[:logs].map(&:pk)).to eq(all_fwd_logs_ordered_pks.slice(2, 2))
        expect(result[:current_page]).to eq(2)
      end
    end

    context 'with user_id filter' do
      it 'returns logs for a specific user_id' do
        result = described_class.find_with_details({ user_id: user1_sl.user_id })
        expect(result[:logs].map(&:pk)).to match_array([fwd_log_u1_now.pk, fwd_log_u1_yest_plus.pk])
        expect(result[:total_entries]).to eq(2)
      end
      it 'returns logs for UNKNOWN_USER_FOR_LOGGING' do
        result = described_class.find_with_details({ user_id: test_unknown_user.user_id })
        expect(result[:logs].map(&:pk)).to eq([fwd_log_unknown_ancient.pk])
        expect(result[:total_entries]).to eq(1)
      end
    end

    context 'with username filter' do
      it 'returns logs matching username (case-insensitive)' do
        result = described_class.find_with_details({ username: 'User1ForSecLog' })
        expect(result[:logs].map(&:pk)).to match_array([fwd_log_u1_now.pk, fwd_log_u1_yest_plus.pk])
      end
    end

    context 'with email filter' do
      it 'returns logs matching email (case-insensitive)' do
        result = described_class.find_with_details({ email: user2_sl.email.upcase })
        expect(result[:logs].map(&:pk)).to eq([fwd_log_u2_yest.pk])
      end
    end

    context 'with action filter' do
      it 'returns logs matching an exact action' do
        result = described_class.find_with_details({ action: 'ACTION_U1_NOW' })
        expect(result[:logs].map(&:pk)).to eq([fwd_log_u1_now.pk])
      end
    end

    context 'with object filter' do
      it 'returns logs matching an exact object' do
        result = described_class.find_with_details({ object: 'ObjectA' })
        expect(result[:logs].map(&:pk)).to match_array([fwd_log_u1_now.pk, fwd_log_u1_yest_plus.pk])
      end
    end

    context 'with details_contains filter' do
      it 'returns logs with matching details (partial, case-insensitive)' do
        result = described_class.find_with_details({ details_contains: 'user1 did something' })
        expect(result[:logs].map(&:pk)).to match_array([fwd_log_u1_now.pk, fwd_log_u1_yest_plus.pk])
      end
    end

    context 'with date_from filter' do
      it 'returns logs from that date onwards' do
        result = described_class.find_with_details({ date_from: time_fwd_yest.to_date.to_s })
        expect(result[:logs].map(&:pk)).to match_array([fwd_log_u1_now.pk, fwd_log_u1_yest_plus.pk, fwd_log_u2_yest.pk])
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with date_to filter' do
      it 'returns logs up to that date (inclusive)' do
        result = described_class.find_with_details({ date_to: time_fwd_yest_plus_sec.to_date.to_s })
        expect(result[:logs].map(&:pk)).to match_array([fwd_log_u1_yest_plus.pk, fwd_log_u2_yest.pk,
                                                        fwd_log_unknown_ancient.pk])
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with combined filters' do
      it 'returns logs matching all criteria' do
        result = described_class.find_with_details({
                                                     user_id: user1_sl.id,
                                                     action: 'ACTION_U1_YEST_PLUS',
                                                     date_from: time_fwd_yest.to_date.to_s,
                                                     date_to: time_fwd_yest_plus_sec.to_date.to_s
                                                   })
        expect(result[:logs].map(&:pk)).to eq([fwd_log_u1_yest_plus.pk])
        expect(result[:total_entries]).to eq(1)
      end
    end
  end
end
