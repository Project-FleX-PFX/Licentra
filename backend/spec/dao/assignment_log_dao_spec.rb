# frozen_string_literal: true

require 'spec_helper'
require 'time'

RSpec.describe AssignmentLogDAO do
  let!(:acting_admin_user) { Fabricate(:user, username: 'AdminActor', email: 'admin_actor@example.com') }
  let!(:target_user1) { Fabricate(:user, username: 'TargetUser1', email: 'target1@example.com') }
  let!(:target_user2) { Fabricate(:user, username: 'TargetUser2', email: 'target2@example.com') }

  let!(:product1) { Fabricate(:product, product_name: 'Awesome Product') }
  let!(:license1) { Fabricate(:license, product: product1, license_name: 'Awesome License Pro') }
  let!(:license2) { Fabricate(:license, product: product1, license_name: 'Awesome License Lite') }

  let!(:assignment1_user1_lic1) do
    Fabricate(:license_assignment, user: target_user1, license: license1)
  end
  let!(:assignment2_user2_lic1) do
    Fabricate(:license_assignment, user: target_user2, license: license1)
  end

  def expected_details_string(acting_user:, action_description:, target_license:, original_assignment_id:)
    actor_info = if acting_user
                   "User '#{acting_user.username}' (ID: #{acting_user.user_id})"
                 else
                   'System'
                 end
    # rubocop:disable Layout/LineLength
    "#{actor_info} performed action '#{action_description}' for license '#{target_license.license_name}' (License ID: #{target_license.license_id}). Assignment ID: #{original_assignment_id}."
    # rubocop:enable Layout/LineLength
  end

  shared_examples 'a specific log creation method' do |action_method_name, action_const|
    let(:log_object_name) { 'LicenseAssignment' }

    context 'with valid parameters' do
      it 'creates a new assignment log' do
        expect do
          described_class.public_send(
            action_method_name,
            acting_user: acting_admin_user,
            target_assignment: assignment1_user1_lic1
          )
        end.to change(AssignmentLog, :count).by(1)
      end

      it 'returns the created log object with correct denormalized data and details', :aggregate_failures do
        log = described_class.public_send(
          action_method_name,
          acting_user: acting_admin_user,
          target_assignment: assignment1_user1_lic1
        )

        expect(log).to be_a(AssignmentLog)
        expect(log.pk).not_to be_nil

        expect(log.license_id).to eq(assignment1_user1_lic1.license.pk)
        expect(log.license_name).to eq(assignment1_user1_lic1.license.license_name)
        expect(log.user_id).to eq(assignment1_user1_lic1.user.pk)
        expect(log.username).to eq(assignment1_user1_lic1.user.username)
        expect(log.email).to eq(assignment1_user1_lic1.user.email)

        expect(log.action).to eq(action_const)
        expect(log.object).to eq(log_object_name)

        expected_details = expected_details_string(
          acting_user: acting_admin_user,
          action_description: action_const,
          target_license: assignment1_user1_lic1.license,
          original_assignment_id: assignment1_user1_lic1.pk
        )
        expect(log.details).to eq(expected_details)
        expect(log.log_timestamp.to_i).to be_within(2).of(Time.now.to_i)
      end

      it 'logs the creation event' do
        allow(described_class).to receive(:log_log_created).and_call_original
        log = described_class.public_send(
          action_method_name,
          acting_user: acting_admin_user,
          target_assignment: assignment1_user1_lic1
        )
        expect(described_class).to have_received(:log_log_created).with(log)
      end
    end

    context 'when target_assignment is missing user' do
      let(:assignment_no_user) { Fabricate.build(:license_assignment, user: nil, license: license1) }
      it 'raises an ArgumentError' do
        allow(assignment_no_user).to receive(:user).and_return(nil)
        expect do
          described_class.public_send(
            action_method_name,
            acting_user: acting_admin_user,
            target_assignment: assignment_no_user
          )
        end.to raise_error(DAO::DAOError, /must have an associated user and license/)
      end
    end

    context 'when target_assignment is missing license' do
      let(:assignment_no_license) { Fabricate.build(:license_assignment, user: target_user1, license: nil) }
      it 'raises an ArgumentError' do
        allow(assignment_no_license).to receive(:license).and_return(nil)
        expect do
          described_class.public_send(
            action_method_name,
            acting_user: acting_admin_user,
            target_assignment: assignment_no_license
          )
        end.to raise_error(DAO::DAOError, /must have an associated user and license/)
      end
    end

    context 'when acting_user is nil (e.g. system action)' do
      it 'creates log with "System" as actor in details' do
        log = described_class.public_send(
          action_method_name,
          acting_user: nil,
          target_assignment: assignment1_user1_lic1
        )
        expected_details = expected_details_string(
          acting_user: nil,
          action_description: action_const,
          target_license: assignment1_user1_lic1.license,
          original_assignment_id: assignment1_user1_lic1.pk
        )
        expect(log.details).to eq(expected_details)
      end
    end
  end

  describe '.log_user_activated_license' do
    it_behaves_like 'a specific log creation method', :log_user_activated_license,
                    AssignmentLogDAO::Actions::USER_ACTIVATED
  end

  describe '.log_admin_activated_license' do
    it_behaves_like 'a specific log creation method', :log_admin_activated_license,
                    AssignmentLogDAO::Actions::ADMIN_ACTIVATED
  end

  describe '.log_user_deactivated_license' do
    it_behaves_like 'a specific log creation method', :log_user_deactivated_license,
                    AssignmentLogDAO::Actions::USER_DEACTIVATED
  end

  describe '.log_admin_deactivated_license' do
    it_behaves_like 'a specific log creation method', :log_admin_deactivated_license,
                    AssignmentLogDAO::Actions::ADMIN_DEACTIVATED
  end

  describe '.log_admin_approved_assignment' do
    it_behaves_like 'a specific log creation method', :log_admin_approved_assignment,
                    AssignmentLogDAO::Actions::ADMIN_APPROVED
  end

  describe '.log_admin_canceled_assignment' do
    it_behaves_like 'a specific log creation method', :log_admin_canceled_assignment,
                    AssignmentLogDAO::Actions::ADMIN_CANCELED
  end

  let!(:log_entry1) do
    Fabricate(:assignment_log,
              source_user: target_user1,
              source_license: license1,
              action: 'FIND_ME_ACTION',
              object: 'FindableObject',
              log_timestamp: Time.now.utc.round)
  end
  let!(:log_entry2) do
    Fabricate(:assignment_log,
              source_user: target_user2,
              source_license: license2,
              action: 'ANOTHER_ACTION_CONTEXT',
              object: 'AnotherObjectContext',
              log_timestamp: (Time.now - 3600).utc.round)
  end

  describe '.find!' do
    context 'when the log exists' do
      it 'returns the log object' do
        found = described_class.find!(log_entry1.pk)
        expect(found).to eq(log_entry1)
      end

      it 'logs the find operation' do
        allow(described_class).to receive(:log_log_found).and_call_original
        described_class.find!(log_entry1.pk)
        expect(described_class).to have_received(:log_log_found).with(log_entry1)
      end
    end

    context 'when the log does not exist' do
      let(:non_existent_id) { log_entry1.pk + 999 }
      it 'raises a DAO::RecordNotFound error' do
        expect do
          described_class.find!(non_existent_id)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.find' do
    it 'returns the log object if it exists' do
      expect(described_class.find(log_entry1.pk)).to eq(log_entry1)
    end

    it 'returns nil if the log does not exist' do
      expect(described_class.find(log_entry1.pk + 999)).to be_nil
    end
  end

  describe '.all' do
    let!(:time_now_all_test) { Time.now.utc.round }
    let!(:log_entry_newest_all) do
      Fabricate(:assignment_log,
                source_user: target_user1,
                source_license: license1,
                log_timestamp: time_now_all_test,
                action: 'NEWEST_ACTION')
    end
    let!(:log_entry_middle_all) do
      Fabricate(:assignment_log,
                source_user: target_user1,
                source_license: license1,
                log_timestamp: time_now_all_test - 1800,
                action: 'MIDDLE_ACTION')
    end
    let!(:log_entry_older_all) do
      Fabricate(:assignment_log,
                source_user: target_user2,
                source_license: license2,
                log_timestamp: time_now_all_test - 3600,
                action: 'OLDER_ACTION')
    end
    let!(:log_entry_oldest_all) do
      Fabricate(:assignment_log,
                source_user: target_user1,
                source_license: license1,
                log_timestamp: time_now_all_test - 7200,
                action: 'OLDEST_ACTION')
    end

    it 'returns all existing logs, ordered by timestamp desc then id desc', :aggregate_failures do
      logs = described_class.all
      expect(logs.count).to eq(6)

      logs.each_cons(2) do |log_a, log_b|
        timestamp_comparison = log_a.log_timestamp <=> log_b.log_timestamp
        if timestamp_comparison == 0
          expect(log_a.pk).to be > log_b.pk
        else
          expect(log_a.log_timestamp).to be >= log_b.log_timestamp
        end
      end
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_logs_fetched).and_call_original
      described_class.all
      expect(described_class).to have_received(:log_logs_fetched).with(6)
    end
  end

  describe '.where' do
    it 'filters logs by criteria and orders them' do
      filtered_logs = described_class.where(action: 'FIND_ME_ACTION')
      expect(filtered_logs.count).to eq(1)
      expect(filtered_logs.first.pk).to eq(log_entry1.pk)
    end
  end

  describe '.delete' do
    let!(:log_to_delete) { Fabricate(:assignment_log) }
    let(:log_id) { log_to_delete.pk }

    it 'removes the log from the database' do
      expect do
        described_class.delete(log_id)
      end.to change(AssignmentLog, :count).by(-1)
      expect(AssignmentLog[log_id]).to be_nil
    end

    it 'returns true' do
      expect(described_class.delete(log_id)).to be true
    end

    it 'logs the deletion' do
      log_obj_before_delete = AssignmentLog[log_id]
      expect(described_class).to receive(:log_log_deleted).with(log_obj_before_delete).and_call_original
      described_class.delete(log_id)
    end

    context 'when the log does not exist' do
      it 'raises a DAO::RecordNotFound error' do
        expect do
          described_class.delete(log_id + 999)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.delete_by_user' do
    let!(:log_for_user1_a) { Fabricate(:assignment_log, source_user: target_user1, action: 'USER1_LOG_A') }
    let!(:log_for_user1_b) { Fabricate(:assignment_log, source_user: target_user1, action: 'USER1_LOG_B') }
    let!(:log_for_user2)   { Fabricate(:assignment_log, source_user: target_user2, action: 'USER2_LOG_A') }

    it 'deletes all logs for the given user_id and returns the count' do
      expect(AssignmentLog.where(user_id: target_user1.pk).count).to eq(3)
      deleted_count = described_class.delete_by_user(target_user1.pk)

      expect(deleted_count).to eq(3)
      expect(AssignmentLog.where(user_id: target_user1.pk).count).to eq(0)
      expect(AssignmentLog[log_entry2.pk]).not_to be_nil
      expect(AssignmentLog[log_for_user2.pk]).not_to be_nil
    end

    it 'returns 0 if no logs exist for the user_id' do
      non_existent_user_id = target_user1.pk + target_user2.pk + 100
      deleted_count = described_class.delete_by_user(non_existent_user_id)
      expect(deleted_count).to eq(0)
    end
  end

  describe '.find_with_details' do
    let!(:time_now) { Time.now.utc.round }
    let!(:time_yesterday) { (time_now - (24 * 60 * 60)).round }
    let!(:time_yesterday_plus_10s) { (time_now - (24 * 60 * 60) + 10).round }
    let!(:time_two_days_ago) { (time_now - (2 * 24 * 60 * 60)).round }

    let!(:log_entry1_user1_lic1_yesterday_plus_10s) do
      Fabricate(:assignment_log,
                source_user: target_user1,
                source_license: license1,
                log_timestamp: time_yesterday_plus_10s,
                action: 'ACTION_USER1_LIC1_YESTERDAY',
                object: 'OBJECT_A')
    end

    let!(:log_entry2_user2_lic2_now) do
      Fabricate(:assignment_log,
                source_user: target_user2,
                source_license: license2,
                log_timestamp: time_now,
                action: 'ACTION_USER2_LIC2_NOW',
                object: 'OBJECT_B')
    end

    let!(:log_entry3_user1_lic2_ancient) do
      Fabricate(:assignment_log,
                source_user: target_user1,
                source_license: license2,
                log_timestamp: time_two_days_ago,
                action: 'ACTION_USER1_LIC2_ANCIENT',
                object: 'OBJECT_A')
    end

    let!(:log_entry4_user2_lic1_yesterday) do
      Fabricate(:assignment_log,
                source_user: target_user2,
                source_license: license1,
                log_timestamp: time_yesterday,
                action: 'ACTION_USER2_LIC1_YESTERDAY',
                object: 'OBJECT_C')
    end

    context 'without filters' do
      it 'returns all logs paginated, ordered by timestamp desc then id desc', :aggregate_failures do
        result = described_class.find_with_details({}, { per_page: 2 })

        expect(result).to be_a(Hash)
        expect(result[:logs].count).to eq(2)

        expected_ordered_pks_page1 = [log_entry2_user2_lic2_now.pk, log_entry1.pk]
        expect(result[:logs].map(&:pk)).to eq(expected_ordered_pks_page1)

        expect(result[:logs][0].username).to eq(target_user2.username)
        expect(result[:logs][0].license_name).to eq(license2.license_name)

        expect(result[:current_page]).to eq(1)
        expect(result[:total_pages]).to eq(3)
        expect(result[:total_entries]).to eq(6)
      end

      it 'fetches the second page correctly' do
        result = described_class.find_with_details({}, { page: 2, per_page: 2 })
        expected_ordered_pks_page2 = [log_entry2.pk, log_entry1_user1_lic1_yesterday_plus_10s.pk]
        expect(result[:logs].map(&:pk)).to eq(expected_ordered_pks_page2)
        expect(result[:current_page]).to eq(2)
      end

      it 'fetches the third page correctly' do
        result = described_class.find_with_details({}, { page: 3, per_page: 2 })
        expected_ordered_pks_page3 = [log_entry4_user2_lic1_yesterday.pk, log_entry3_user1_lic2_ancient.pk]
        expect(result[:logs].map(&:pk)).to eq(expected_ordered_pks_page3)
        expect(result[:current_page]).to eq(3)
      end

      it 'logs the info message' do
        expect(described_class).to receive(:log_info).with(/Fetched \d+ assignment logs/).and_call_original
        described_class.find_with_details
      end
    end

    context 'with user_id filter' do
      it 'returns only logs related to the specified user_id' do
        result = described_class.find_with_details({ user_id: target_user1.pk })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to match_array([
                                         log_entry1.pk,
                                         log_entry1_user1_lic1_yesterday_plus_10s.pk,
                                         log_entry3_user1_lic2_ancient.pk
                                       ])
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with license_id filter' do
      it 'returns only logs related to the specified license_id' do
        result = described_class.find_with_details({ license_id: license1.pk })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to match_array([
                                         log_entry1.pk,
                                         log_entry1_user1_lic1_yesterday_plus_10s.pk,
                                         log_entry4_user2_lic1_yesterday.pk
                                       ])
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with action filter (partial, case-insensitive)' do
      it 'returns only logs matching the action' do
        result = described_class.find_with_details({ action: '_lic1_yesterday' })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([log_entry1_user1_lic1_yesterday_plus_10s.pk,
                                        log_entry4_user2_lic1_yesterday.pk])
        expect(result[:total_entries]).to eq(2)
      end
    end

    context 'with object filter (partial, case-insensitive)' do
      it 'returns only logs matching the object' do
        result = described_class.find_with_details({ object: 'Object_A' })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([log_entry1_user1_lic1_yesterday_plus_10s.pk, log_entry3_user1_lic2_ancient.pk])
        expect(result[:total_entries]).to eq(2)
      end
    end

    context 'with date_from filter' do
      it 'returns logs from a specific date onwards' do
        result = described_class.find_with_details({ date_from: time_yesterday.to_date.to_s })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([
                                         log_entry2_user2_lic2_now.pk,
                                         log_entry1.pk,
                                         log_entry2.pk,
                                         log_entry1_user1_lic1_yesterday_plus_10s.pk,
                                         log_entry4_user2_lic1_yesterday.pk
                                       ])
        expect(result[:total_entries]).to eq(5)
      end
    end

    context 'with date_to filter' do
      it 'returns logs up to a specific date (inclusive)' do
        result = described_class.find_with_details({ date_to: time_yesterday_plus_10s.to_date.to_s })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([log_entry1_user1_lic1_yesterday_plus_10s.pk,
                                        log_entry4_user2_lic1_yesterday.pk,
                                        log_entry3_user1_lic2_ancient.pk])
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with combined filters' do
      it 'returns logs matching user_id, license_id, and date range' do
        result = described_class.find_with_details(
          {
            user_id: target_user1.pk,
            license_id: license1.pk,
            date_from: time_yesterday.to_date.to_s,
            date_to: time_yesterday_plus_10s.to_date.to_s
          }
        )
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to eq([log_entry1_user1_lic1_yesterday_plus_10s.pk])
        expect(result[:total_entries]).to eq(1)
      end
    end
  end
end
