# frozen_string_literal: true

require 'spec_helper'
require 'time'

RSpec.describe AssignmentLogDAO do
  let!(:user1) { Fabricate(:user, username: 'User1ForLogTest') }
  let!(:user2) { Fabricate(:user, username: 'User2ForLogTest') }
  let!(:product1) { Fabricate(:product, product_name: 'ProductForLogTest') }
  let!(:license1) { Fabricate(:license, product: product1, license_name: 'LicenseForLogTest') }
  let!(:license_assignment1) { Fabricate(:license_assignment, user: user1, license: license1) }
  let!(:license_assignment2) { Fabricate(:license_assignment, user: user2, license: license1) }

  let(:valid_attributes_for_create) do
    Fabricate.attributes_for(:assignment_log,
                             assignment_id: license_assignment1.pk)
  end

  describe '.create_log' do
    let(:log_action) { AssignmentLogDAO::Actions::USER_ACTIVATED }
    let(:log_object) { 'LicenseAssignmentActivity' }
    let(:log_details) { 'User X activated their license via new method.' }

    context 'with valid parameters' do
      it 'creates a new assignment log' do
        expect do
          described_class.create_log(
            action: log_action,
            object: log_object,
            assignment: license_assignment1,
            details: log_details
          )
        end.to change(AssignmentLog, :count).by(1)
      end

      it 'returns the created log object', :aggregate_failures do
        log = described_class.create_log(
          action: log_action,
          object: log_object,
          assignment: license_assignment1,
          details: log_details
        )
        expect(log).to be_a(AssignmentLog)
        expect(log.assignment_id).to eq(license_assignment1.pk)
        expect(log.action).to eq(log_action)
        expect(log.object).to eq(log_object)
        expect(log.details).to eq(log_details)
        expect(log.pk).not_to be_nil
        expect(log.log_timestamp.to_i).to be_within(1).of(Time.now.to_i)
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_log_created).and_call_original
        log = described_class.create_log(
          action: log_action,
          object: log_object,
          assignment: license_assignment1
        )
        expect(described_class).to have_received(:log_log_created).with(log)
      end

      context 'when assignment is nil' do
        it 'creates a log with nil assignment_id', :aggregate_failures do
          log = described_class.create_log(
            action: 'SYSTEM_ACTION',
            object: 'SystemProcess',
            assignment: nil,
            details: 'System maintenance.'
          )
          expect(log).to be_a(AssignmentLog)
          expect(log.assignment_id).to be_nil
          expect(log.action).to eq('SYSTEM_ACTION')
          expect(log.object).to eq('SystemProcess')
        end
      end
    end

    context 'with invalid parameters (missing object)' do
      it 'does not create a new log and calls handle_validation_error' do
        expect(described_class).to receive(:handle_validation_error).and_call_original
        log_entry = described_class.create_log(
          action: log_action,
          object: nil,
          assignment: license_assignment1
        )
        expect(log_entry).to be_nil
        expect(AssignmentLog.count).to eq(0)
      end
    end

    context 'with invalid parameters (missing action)' do
      it 'does not create a new log and calls handle_validation_error' do
        expect(described_class).to receive(:handle_validation_error).and_call_original
        log_entry = described_class.create_log(
          action: nil,
          object: log_object,
          assignment: license_assignment1
        )
        expect(log_entry).to be_nil
        expect(AssignmentLog.count).to eq(0)
      end
    end
  end

  describe '.create' do
    context 'with valid attributes (including object)' do
      it 'creates a new assignment log' do
        expect do
          described_class.create(valid_attributes_for_create)
        end.to change(AssignmentLog, :count).by(1)
      end

      it 'returns the created log object', :aggregate_failures do
        log = described_class.create(valid_attributes_for_create)
        expect(log).to be_a(AssignmentLog)
        expect(log.assignment_id).to eq(license_assignment1.pk)
        expect(log.action).to eq(valid_attributes_for_create[:action])
        expect(log.object).to eq(valid_attributes_for_create[:object])
        expect(log.pk).not_to be_nil
        expect(log.log_timestamp.to_i).to be_within(1).of(Time.now.to_i)
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_log_created).and_call_original
        log = described_class.create(valid_attributes_for_create)
        expect(described_class).to have_received(:log_log_created).with(log)
      end
    end

    context 'with invalid attributes (missing object)' do
      let(:invalid_attrs) { valid_attributes_for_create.merge(object: nil) }

      it 'does not create a new log and calls handle_validation_error' do
        expect(described_class).to receive(:handle_validation_error).and_call_original
        log_entry = described_class.create(invalid_attrs)
        expect(log_entry).to be_nil
        expect(AssignmentLog.count).to eq(0)
      end
    end

    context 'with invalid attributes (missing action)' do
      let(:invalid_attrs) { valid_attributes_for_create.merge(action: nil) }

      it 'does not create a new log and calls handle_validation_error' do
        expect(described_class).to receive(:handle_validation_error).and_call_original
        log_entry = described_class.create(invalid_attrs)
        expect(log_entry).to be_nil
        expect(AssignmentLog.count).to eq(0)
      end
    end
  end

  describe '.find!' do
    let!(:log1) { Fabricate(:assignment_log, assignment_id: license_assignment1.pk) }

    context 'when the log exists' do
      it 'returns the log object' do
        found = described_class.find!(log1.pk)
        expect(found).to eq(log1)
      end

      it 'logs the find operation' do
        allow(described_class).to receive(:log_log_found).and_call_original
        described_class.find!(log1.pk)
        expect(described_class).to have_received(:log_log_found).with(log1)
      end
    end

    context 'when the log does not exist' do
      let(:non_existent_id) { log1.pk + 999 }

      it 'raises a DAO::RecordNotFound error' do
        expect do
          described_class.find!(non_existent_id)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.find' do
    let!(:log1) { Fabricate(:assignment_log, assignment_id: license_assignment1.pk) }

    it 'returns the log object if it exists' do
      expect(described_class.find(log1.pk)).to eq(log1)
    end

    it 'returns nil if the log does not exist' do
      expect(described_class.find(log1.pk + 999)).to be_nil
    end
  end

  describe '.all' do
    let!(:log_a) { Fabricate(:assignment_log, action: 'ACTION_A_ALL') }
    let!(:log_b) { Fabricate(:assignment_log, action: 'ACTION_B_ALL') }

    it 'returns all existing logs, ordered by timestamp desc then id desc', :aggregate_failures do
      log_c = Fabricate(:assignment_log, action: 'ACTION_C_ALL', log_timestamp: Time.now - 60)
      log_d = Fabricate(:assignment_log, action: 'ACTION_D_ALL', log_timestamp: Time.now)

      logs = described_class.all
      expect(logs.count).to eq(4)
      expect(logs.map(&:action)).to eq(%w[ACTION_D_ALL ACTION_B_ALL ACTION_A_ALL ACTION_C_ALL])
    end

    it 'logs the fetch operation' do
      Fabricate(:assignment_log)
      allow(described_class).to receive(:log_logs_fetched).and_call_original
      described_class.all
      expect(described_class).to have_received(:log_logs_fetched).with(AssignmentLog.count)
    end
  end

  describe '.update' do
    let!(:log_to_update) do
      Fabricate(:assignment_log, action: 'OLD_ACTION', object: 'OldObject', details: 'Old Details')
    end
    let(:update_attributes) { { details: 'New details', object: 'NewObjectToUpdate' } }

    context 'with valid attributes' do
      it 'updates the log attributes', :aggregate_failures do
        updated_log = described_class.update(log_to_update.pk, update_attributes)
        log_to_update.refresh
        expect(log_to_update.details).to eq('New details')
        expect(log_to_update.object).to eq('NewObjectToUpdate')
        expect(updated_log.details).to eq('New details')
        expect(updated_log.object).to eq('NewObjectToUpdate')
        expect(updated_log.action).to eq('OLD_ACTION')
      end

      it 'logs the update' do
        allow(described_class).to receive(:log_log_updated).and_call_original
        described_class.update(log_to_update.pk, update_attributes)
        expect(described_class).to have_received(:log_log_updated).with(an_object_having_attributes(
                                                                          details: 'New details', object: 'NewObjectToUpdate'
                                                                        ))
      end
    end

    context 'with invalid attributes (setting object to nil)' do
      let(:invalid_update_attributes) { { object: nil } }

      it 'does not update the log and calls handle_validation_error' do
        original_object = log_to_update.object
        expect(described_class).to receive(:handle_validation_error) do |_model, _context, messages|
          expect(messages).to match(/Object darf nicht leer sein|object can't be blank/i)
        end.and_call_original

        updated_log = described_class.update(log_to_update.pk, invalid_update_attributes)
        expect(updated_log).to be_nil

        log_to_update.refresh
        expect(log_to_update.object).to eq(original_object)
      end
    end

    context 'when the log does not exist' do
      it 'raises a DAO::RecordNotFound error' do
        expect do
          described_class.update(log_to_update.pk + 999, details: 'something')
        end.to raise_error(DAO::RecordNotFound)
      end
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
      expect(described_class).to receive(:log_log_deleted).with(an_object_having_attributes(pk: log_id)).and_call_original
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

  describe '.find_by_assignment' do
    let!(:assignment_for_find) { Fabricate(:license_assignment) }
    let!(:log_a) { Fabricate(:assignment_log, assignment_id: assignment_for_find.pk, action: 'ASSIGNED') }
    let!(:log_b) { Fabricate(:assignment_log, assignment_id: assignment_for_find.pk, action: 'DEACTIVATED') }
    let!(:other_assignment_for_find) { Fabricate(:license_assignment) }
    let!(:other_log) { Fabricate(:assignment_log, assignment_id: other_assignment_for_find.pk) }

    it 'returns logs only for the specified assignment, ordered desc by timestamp' do
      logs = described_class.find_by_assignment(assignment_for_find.pk)
      expect(logs.map(&:pk)).to match_array([log_a.pk, log_b.pk])
      expect(logs).not_to include(other_log)
      expect(logs.first.log_timestamp >= logs.last.log_timestamp).to be true if logs.size > 1
    end

    it 'returns an empty array if assignment has no logs' do
      new_assignment = Fabricate(:license_assignment)
      logs = described_class.find_by_assignment(new_assignment.pk)
      expect(logs).to be_empty
    end
  end

  describe '.delete_by_assignment' do
    let!(:assignment_for_delete) { Fabricate(:license_assignment) }
    let!(:log_a_del) { Fabricate(:assignment_log, assignment_id: assignment_for_delete.pk) }
    let!(:log_b_del) { Fabricate(:assignment_log, assignment_id: assignment_for_delete.pk) }
    let!(:other_assignment_for_delete) { Fabricate(:license_assignment) }
    let!(:other_log_del) { Fabricate(:assignment_log, assignment_id: other_assignment_for_delete.pk) }

    it 'deletes all logs for the given assignment and returns the count' do
      expect(AssignmentLog.where(assignment_id: assignment_for_delete.pk).count).to eq(2)
      deleted_count = described_class.delete_by_assignment(assignment_for_delete.pk)
      expect(deleted_count).to eq(2)
      expect(AssignmentLog.where(assignment_id: assignment_for_delete.pk).count).to eq(0)
      expect(AssignmentLog[other_log_del.pk]).not_to be_nil
    end

    it 'returns 0 if no logs exist for the assignment' do
      new_assignment = Fabricate(:license_assignment)
      deleted_count = described_class.delete_by_assignment(new_assignment.pk)
      expect(deleted_count).to eq(0)
    end

    it 'logs the deletion' do
      allow(described_class).to receive(:log_logs_deleted_for_assignment).and_call_original
      described_class.delete_by_assignment(assignment_for_delete.pk)
      expect(described_class).to have_received(:log_logs_deleted_for_assignment).with(assignment_for_delete.pk, 2)
    end
  end

  describe '.find_with_details' do
    let!(:user_a_detail) { user1 }
    let!(:user_b_detail) { user2 }
    let!(:prod_a_detail) { product1 }
    let!(:lic_a_detail) { license1 }

    let!(:assign_a1_detail) { Fabricate(:license_assignment, user: user_a_detail, license: lic_a_detail) }
    let!(:assign_a2_detail) do
      Fabricate(:license_assignment, user: user_a_detail, license: lic_a_detail)
    end
    let!(:assign_b1_detail) { Fabricate(:license_assignment, user: user_b_detail, license: lic_a_detail) }

    let!(:time_now) { Time.now.utc.round }
    let!(:time_yesterday) { (time_now - (24 * 60 * 60)).round }
    let!(:time_two_days_ago) { (time_now - (2 * 24 * 60 * 60)).round }

    let!(:log1_detail) do
      Fabricate(:assignment_log, license_assignment: assign_a1_detail, action: 'ASSIGNED_A1', object: 'LicenseAssignment',
                                 log_timestamp: time_yesterday)
    end
    let!(:log2_detail) do
      Fabricate(:assignment_log, license_assignment: assign_a1_detail, action: 'REVOKED_A1',  object: 'LicenseAssignment',
                                 log_timestamp: time_now)
    end
    let!(:log3_detail) do
      Fabricate(:assignment_log, license_assignment: assign_a2_detail, action: 'ASSIGNED_A2', object: 'UserProfileUpdate',
                                 log_timestamp: time_two_days_ago)
    end
    let!(:log4_detail) do
      Fabricate(:assignment_log, license_assignment: assign_b1_detail, action: 'ASSIGNED_B1', object: 'LicenseAssignment',
                                 log_timestamp: time_yesterday)
    end

    context 'without filters' do
      it 'returns all logs paginated with details, ordered by timestamp desc then id desc', :aggregate_failures do
        result = described_class.find_with_details({}, { per_page: 2 })

        expect(result).to be_a(Hash)
        expect(result[:logs].count).to eq(2)
        expect(result[:logs][0].pk).to eq(log2_detail.pk)
        expect([log1_detail.pk, log4_detail.pk]).to include(result[:logs][1].pk)

        expect(result[:logs][0].associations).to have_key(:license_assignment)
        expect(result[:logs][0].license_assignment&.associations).to have_key(:user)
        expect(result[:logs][0].license_assignment&.user&.username).to eq(user_a_detail.username)

        expect(result[:current_page]).to eq(1)
        expect(result[:total_pages]).to eq(2)
        expect(result[:total_entries]).to eq(4)
      end

      it 'fetches the second page correctly', :aggregate_failures do
        result = described_class.find_with_details({}, { page: 2, per_page: 2 })
        expect(result[:logs].count).to eq(2)
        remaining_pks = [log1_detail.pk, log4_detail.pk,
                         log3_detail.pk] - described_class.find_with_details({}, { per_page: 2 })[:logs].map(&:pk)
        expect(result[:logs].map(&:pk)).to match_array(remaining_pks)

        expect(result[:current_page]).to eq(2)
      end

      it 'logs the info message' do
        expect(described_class).to receive(:log_info).with(/Fetched \d+ assignment logs/).and_call_original
        described_class.find_with_details
      end
    end

    context 'with user filter' do
      it 'returns only logs related to the specified user' do
        result = described_class.find_with_details({ user_id: user_a_detail.user_id })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to match_array([log1_detail.pk, log2_detail.pk, log3_detail.pk])
        expect(log_pks).not_to include(log4_detail.pk)
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with action filter (partial, case-insensitive)' do
      it 'returns only logs matching the action' do
        result = described_class.find_with_details({ action: ' assigned_a' })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([log1_detail.pk, log3_detail.pk])
        expect(result[:total_entries]).to eq(2)
      end
    end

    context 'with object filter (partial, case-insensitive)' do
      it 'returns only logs matching the object' do
        result = described_class.find_with_details({ object: 'LicenseAssign' })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([log1_detail.pk, log2_detail.pk, log4_detail.pk])
        expect(log_pks).not_to include(log3_detail.pk)
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with date_from filter' do
      it 'returns logs from a specific date onwards' do
        result = described_class.find_with_details({ date_from: time_yesterday.to_date.to_s })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([log1_detail.pk, log2_detail.pk, log4_detail.pk])
        expect(log_pks).not_to include(log3_detail.pk)
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with date_to filter' do
      it 'returns logs up to a specific date (inclusive)' do
        result = described_class.find_with_details({ date_to: time_yesterday.to_date.to_s })
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to match_array([log1_detail.pk, log3_detail.pk, log4_detail.pk])
        expect(log_pks).not_to include(log2_detail.pk)
        expect(result[:total_entries]).to eq(3)
      end
    end

    context 'with combined filters' do
      it 'returns logs matching user, object, and date range' do
        result = described_class.find_with_details(
          {
            user_id: user_a_detail.user_id,
            object: 'LicenseAssignment',
            date_from: time_yesterday.to_date.to_s,
            date_to: time_yesterday.to_date.to_s
          }
        )
        log_pks = result[:logs].map(&:pk)
        expect(log_pks).to eq([log1_detail.pk])
        expect(result[:total_entries]).to eq(1)
      end
    end
  end
end
