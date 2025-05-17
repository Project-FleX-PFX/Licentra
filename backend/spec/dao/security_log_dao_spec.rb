# frozen_string_literal: true

require 'spec_helper'
require 'time'

RSpec.describe SecurityLogDAO do
  let!(:user_for_log_tests) { Fabricate(:user, username: 'LogTestUser') }
  let!(:another_user_for_logs) { Fabricate(:user, username: 'AnotherLogUser') }

  let(:valid_attributes_for_create) do
    Fabricate.attributes_for(:security_log, user_id: user_for_log_tests.id)
  end

  before(:each) { SecurityLog.dataset.delete }

  describe '.create_log' do
    let(:log_action) { SecurityLogDAO::Actions::USER_CREATED }
    let(:log_object) { 'Admin' }
    let(:log_details) { "New user account created for #{user_for_log_tests.username}." }

    context 'with valid parameters including a user' do
      it 'creates a new security log' do
        expect do
          described_class.create_log(
            action: log_action,
            object: log_object,
            user: user_for_log_tests,
            details: log_details
          )
        end.to change(SecurityLog, :count).by(1)
      end

      it 'returns the created log object', :aggregate_failures do
        log = described_class.create_log(
          action: log_action,
          object: log_object,
          user: user_for_log_tests,
          details: log_details
        )
        expect(log).to be_a(SecurityLog)
        expect(log.user_id).to eq(user_for_log_tests.id)
        expect(log.action).to eq(log_action)
        expect(log.object).to eq(log_object)
        expect(log.details).to eq(log_details)
        expect(log.pk).not_to be_nil
        expect(log.log_timestamp.to_i).to be_within(1).of(Time.now.to_i)
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_security_log_created).and_call_original
        log = described_class.create_log(
          action: log_action,
          object: log_object,
          user: user_for_log_tests
        )
        expect(described_class).to have_received(:log_security_log_created).with(log)
      end
    end

    context 'with valid parameters without a user (system log)' do
      it 'creates a log with nil user_id', :aggregate_failures do
        system_action = SecurityLogDAO::Actions::PRODUCT_DELETED
        system_object = 'Product'
        log = described_class.create_log(
          action: system_action,
          object: system_object,
          user: nil,
          details: 'Product XYZ was automatically pruned due to inactivity.'
        )
        expect(log).to be_a(SecurityLog)
        expect(log.user_id).to be_nil
        expect(log.action).to eq(system_action)
        expect(log.object).to eq(system_object)
      end
    end

    context 'with invalid parameters (missing object)' do
      it 'does not create a new log and raises DAO::ValidationError' do
        expect do
          described_class.create_log(
            action: log_action,
            object: nil,
            user: user_for_log_tests
          )
        end.to raise_error(DAO::ValidationError, /object is not present/)
        expect(SecurityLog.count).to eq(0)
      end
    end

    context 'with invalid parameters (missing action)' do
      it 'does not create a new log and calls handle_validation_error' do
        expect do
          described_class.create_log(
            action: nil,
            object: log_object,
            user: user_for_log_tests
          )
        end.to raise_error(DAO::ValidationError, /action is not present/)
        expect(SecurityLog.count).to eq(0)
      end
    end

    describe '.create' do
      context 'with valid attributes' do
        it 'creates a new security log' do
          expect do
            described_class.create(valid_attributes_for_create)
          end.to change(SecurityLog, :count).by(1)
        end

        it 'returns the created log object', :aggregate_failures do
          log = described_class.create(valid_attributes_for_create)
          expect(log).to be_a(SecurityLog)
          expect(log.user_id).to eq(user_for_log_tests.id)
          expect(log.action).to eq(valid_attributes_for_create[:action])
          expect(log.object).to eq(valid_attributes_for_create[:object])
          expect(log.pk).not_to be_nil
          expect(log.log_timestamp.to_i).to be_within(1).of(Time.now.to_i)
        end
      end

      context 'with invalid attributes (missing object)' do
        let(:invalid_attrs) { valid_attributes_for_create.merge(object: nil) }
        it 'does not create a new log and raises a DAO::ValidationError' do
          expect do
            described_class.create(invalid_attrs)
          end.to raise_error(DAO::ValidationError, /object is not present/)
          expect(SecurityLog.count).to eq(0)
        end
      end
    end

    describe '.find!' do
      let!(:log1) { Fabricate(:security_log, user: user_for_log_tests) }

      context 'when the log exists' do
        it 'returns the log object' do
          found = described_class.find!(log1.pk)
          expect(found).to eq(log1)
        end

        it 'logs the find operation' do
          allow(described_class).to receive(:log_security_log_found).and_call_original
          described_class.find!(log1.pk)
          expect(described_class).to have_received(:log_security_log_found).with(log1)
        end
      end

      context 'when the log does not exist' do
        let(:non_existent_id) { log1.pk + 9999 }
        it 'raises a DAO::RecordNotFound error' do
          expect do
            described_class.find!(non_existent_id)
          end.to raise_error(DAO::RecordNotFound, /SecurityLog with ID #{non_existent_id} not found/)
        end
      end
    end

    describe '.find' do
      let!(:log1) { Fabricate(:security_log, user: user_for_log_tests) }
      it 'returns the log object if it exists' do
        expect(described_class.find(log1.pk)).to eq(log1)
      end
      it 'returns nil if the log does not exist' do
        expect(described_class.find(log1.pk + 9999)).to be_nil
      end
    end

    describe '.all' do
      let!(:log_a_sl) do
        Fabricate(:security_log, action: SecurityLogDAO::Actions::LOGIN_SUCCESS, log_timestamp: Time.now - 120)
      end
      let!(:log_b_sl) do
        Fabricate(:security_log, action: SecurityLogDAO::Actions::USER_DELETED, log_timestamp: Time.now - 60)
      end
      let!(:log_c_sl) do
        Fabricate(:security_log, action: SecurityLogDAO::Actions::PASSWORD_CHANGED, log_timestamp: Time.now)
      end

      it 'returns all existing logs, ordered by timestamp desc then id desc', :aggregate_failures do
        logs = described_class.all
        expect(logs.count).to eq(3)
        expect(logs.map(&:pk)).to eq([log_c_sl.pk, log_b_sl.pk, log_a_sl.pk])
      end

      it 'logs the fetch operation' do
        allow(described_class).to receive(:log_security_logs_fetched).and_call_original
        described_class.all
        expect(described_class).to have_received(:log_security_logs_fetched).with(3)
      end
    end

    describe '.update' do
      let!(:log_to_update_sl) { Fabricate(:security_log, details: 'Original details') }
      let(:update_attrs_sl) { { details: 'Updated security details' } }

      context 'with valid attributes (only details)' do
        it 'updates the log attributes', :aggregate_failures do
          updated_log = described_class.update(log_to_update_sl.pk, update_attrs_sl)
          log_to_update_sl.refresh
          expect(log_to_update_sl.details).to eq('Updated security details')
          expect(updated_log.details).to eq('Updated security details')
        end

        it 'logs the update' do
          allow(described_class).to receive(:log_security_log_updated).and_call_original
          described_class.update(log_to_update_sl.pk, update_attrs_sl)
          expect(described_class).to have_received(:log_security_log_updated).with(an_object_having_attributes(details: 'Updated security details'))
        end
      end

      context 'attempting to update restricted fields' do
        let(:restricted_update_attrs) { { action: 'NEW_ACTION_HACK', object: nil } }
        it 'does not update the object field and other fields are updated if valid' do
          original_action = log_to_update_sl.action
          original_object = log_to_update_sl.object
          attempted_update_attrs = { object: 'SHOULD_BE_IGNORED', details: 'Details successfully updated' }

          updated_log = described_class.update(log_to_update_sl.pk, attempted_update_attrs)
          expect(updated_log).not_to be_nil

          log_to_update_sl.refresh
          expect(log_to_update_sl.action).to eq(original_action)
          expect(log_to_update_sl.object).to eq(original_object)
          expect(log_to_update_sl.details).to eq('Details successfully updated')
        end
      end
    end

    describe '.delete' do
      let!(:log_to_delete_sl) { Fabricate(:security_log) }
      let(:log_id_sl) { log_to_delete_sl.pk }

      it 'removes the log from the database' do
        expect { described_class.delete(log_id_sl) }.to change(SecurityLog, :count).by(-1)
        expect(SecurityLog[log_id_sl]).to be_nil
      end

      it 'returns true' do
        expect(described_class.delete(log_id_sl)).to be true
      end
    end

    describe '.find_by_user' do
      let!(:log_user_a_1) do
        Fabricate(:security_log, user: user_for_log_tests, action: 'ACTION_U1_1', log_timestamp: Time.now - 10)
      end
      let!(:log_user_a_2) do
        Fabricate(:security_log, user: user_for_log_tests, action: 'ACTION_U1_2', log_timestamp: Time.now)
      end
      let!(:log_user_b_1) { Fabricate(:security_log, user: another_user_for_logs, action: 'ACTION_U2_1') }

      it 'returns logs only for the specified user, ordered by timestamp desc' do
        logs = described_class.find_by_user(user_for_log_tests.user_id)
        expect(logs.map(&:pk)).to eq([log_user_a_2.pk, log_user_a_1.pk])
        expect(logs.map(&:pk)).not_to include(log_user_b_1.pk)
      end

      it 'returns an empty array if user has no logs' do
        yet_another_user = Fabricate(:user)
        logs = described_class.find_by_user(yet_another_user.id)
        expect(logs).to be_empty
      end
    end

    describe '.find_with_details' do
      let!(:user_detail_sl1) { Fabricate(:user, username: 'DetailUserSL1') }
      let!(:user_detail_sl2) { Fabricate(:user, username: 'DetailUserSL2') }

      let!(:time_now_sl) { Time.now.utc.round }
      let!(:time_yesterday_sl) { (time_now_sl - (24 * 60 * 60)).round }
      let!(:time_two_days_ago_sl) { (time_now_sl - (2 * 24 * 60 * 60)).round }

      let!(:s_log1) do
        Fabricate(:security_log, user: user_detail_sl1, action: SecurityLogDAO::Actions::LOGIN_SUCCESS,
                                 object: user_detail_sl1.username, details: 'Login from IP 1.2.3.4', log_timestamp: time_yesterday_sl)
      end
      let!(:s_log2) do
        Fabricate(:security_log, user: user_detail_sl1, action: SecurityLogDAO::Actions::PASSWORD_CHANGED,
                                 object: user_detail_sl1.username, details: 'Password changed by user', log_timestamp: time_now_sl)
      end
      let!(:s_log3) do
        Fabricate(:security_log, user: user_detail_sl2, action: SecurityLogDAO::Actions::USER_UPDATED,
                                 object: user_detail_sl2.username, details: 'User profile updated by admin', log_timestamp: time_two_days_ago_sl)
      end
      let!(:s_log4) do
        Fabricate(:security_log, user: nil, action: SecurityLogDAO::Actions::PRODUCT_DELETED,
                                 object: 'Product', details: 'System auto-deleted product X', log_timestamp: time_yesterday_sl)
      end

      context 'without filters' do
        it 'returns all logs paginated with user details, ordered by timestamp desc', :aggregate_failures do
          result = described_class.find_with_details({}, { per_page: 2 })
          expect(result[:logs].count).to eq(2)
          expect(result[:logs][0].pk).to eq(s_log2.pk)
          expect([s_log1.pk, s_log4.pk]).to include(result[:logs][1].pk)

          expect(result[:logs][0].user&.username).to eq(user_detail_sl1.username)
          expect(result[:logs][0].user&.username).to eq(user_detail_sl1.username)
          expect(result[:total_entries]).to eq(4)
        end
      end

      context 'with user_id filter' do
        it 'returns only logs for that user' do
          result = described_class.find_with_details({ user_id: user_detail_sl1.user_id })
          expect(result[:logs].map(&:pk)).to match_array([s_log1.pk, s_log2.pk])
          expect(result[:total_entries]).to eq(2)
        end
      end

      context 'with action filter (partial match)' do
        it 'returns logs matching the action' do
          result = described_class.find_with_details({ action: 'success' })
          expect(result[:logs].map(&:pk)).to eq([s_log1.pk])
          expect(result[:total_entries]).to eq(1)
        end
      end

      context 'with object filter (partial match)' do
        it 'returns logs matching the object type' do
          result = described_class.find_with_details({ object: 'DetailUserSL2' })
          expect(result[:logs].map(&:pk)).to eq([s_log3.pk])
          expect(result[:total_entries]).to eq(1)
        end
      end

      context 'with details_contains filter' do
        it 'returns logs where details contain the string' do
          result = described_class.find_with_details({ details_contains: 'IP 1.2.3.4' })
          expect(result[:logs].map(&:pk)).to eq([s_log1.pk])
          expect(result[:total_entries]).to eq(1)
        end
      end

      context 'with date_from filter' do
        it 'returns logs from date onwards' do
          result = described_class.find_with_details({ date_from: time_yesterday_sl.to_date.to_s })
          expect(result[:logs].map(&:pk)).to match_array([s_log1.pk, s_log2.pk, s_log4.pk])
          expect(result[:total_entries]).to eq(3)
        end
      end

      context 'with combined filters (user and action)' do
        it 'returns logs matching user and action' do
          result = described_class.find_with_details({ user_id: user_detail_sl1.id,
                                                       action: SecurityLogDAO::Actions::LOGIN_SUCCESS })
          expect(result[:logs].map(&:pk)).to eq([s_log1.pk])
          expect(result[:total_entries]).to eq(1)
        end
      end
    end
  end
end
