# frozen_string_literal: true

require 'spec_helper'
require 'time'

RSpec.describe AssignmentLogDAO do
  let!(:user1) { Fabricate(:user) }
  let!(:user2) { Fabricate(:user) }
  let!(:product1) { Fabricate(:product) }
  let!(:license1) { Fabricate(:license, product: product1) }
  let!(:license_assignment1) { Fabricate(:license_assignment, user: user1, license: license1) }
  let!(:license_assignment2) { Fabricate(:license_assignment, user: user2, license: license1) }

  let(:valid_attributes) do
    Fabricate.attributes_for(:assignment_log, assignment_id: license_assignment1.pk)
  end

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new assignment log' do
        expect do
          described_class.create(valid_attributes)
        end.to change(AssignmentLog, :count).by(1)
      end

      it 'returns the created log object', :aggregate_failures do
        log = described_class.create(valid_attributes)
        expect(log).to be_a(AssignmentLog)
        expect(log.assignment_id).to eq(license_assignment1.pk)
        expect(log.action).to eq(valid_attributes[:action])
        expect(log.pk).not_to be_nil
        expect(log.log_timestamp).to be_a(Time)
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_log_created)
        log = described_class.create(valid_attributes)
        expect(described_class).to have_received(:log_log_created).with(log)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { valid_attributes.merge(action: nil) }

      it 'does not create a new log' do
        expect do
          described_class.create(invalid_attributes)
        rescue DAO::DAOError
        end.not_to change(AssignmentLog, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        rescued_exception = nil
        begin
          described_class.create(invalid_attributes)
        rescue DAO::DAOError => e
          rescued_exception = e
        end

        expect(rescued_exception).to be_a(DAO::ValidationError)
        expect(rescued_exception.message).to match(/Validation failed while creating assignment log/i)
        expect(rescued_exception.errors).to have_key(:action)
        # Die tatsächliche Fehlermeldung ist wahrscheinlich "is not present" oder "cannot be empty/null"
        expect(rescued_exception.errors[:action]).to include(/cannot be (empty|null|blank)|is not present/i)
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
        allow(described_class).to receive(:log_log_found)
        described_class.find!(log1.pk)
        expect(described_class).to have_received(:log_log_found).with(log1)
      end
    end

    context 'when the log does not exist' do
      let(:non_existent_id) { 99_999 }

      it 'raises a RecordNotFound error' do
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
      expect(described_class.find(99_999)).to be_nil
    end
  end

  describe '.all' do
    let!(:log_a) { Fabricate(:assignment_log, action: 'ACTION_A') }
    let!(:log_b) { Fabricate(:assignment_log, action: 'ACTION_B') }

    before(:all) do
      AssignmentLog.dataset.delete
    end

    it 'returns all existing logs', :aggregate_failures do
      logs = described_class.all
      expect(logs.count).to eq(2)
      expect(logs.map(&:action)).to match_array(%w[ACTION_A ACTION_B])
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_logs_fetched)
      described_class.all
      expect(described_class).to have_received(:log_logs_fetched).with(2)
    end
  end

  describe '.update' do
    let!(:log_to_update) { Fabricate(:assignment_log, action: 'OLD_ACTION') }
    let(:update_attributes) { { details: 'New details' } }

    context 'with valid attributes' do
      it 'updates the log attributes', :aggregate_failures do
        updated_log = described_class.update(log_to_update.pk, update_attributes)
        log_to_update.refresh
        expect(log_to_update.details).to eq('New details')
        expect(updated_log.details).to eq('New details')
        expect(updated_log.action).to eq('OLD_ACTION')
      end

      it 'logs the update' do
        allow(described_class).to receive(:log_log_updated)
        described_class.update(log_to_update.pk, update_attributes)
        expect(described_class).to have_received(:log_log_updated).with(an_object_having_attributes(details: 'New details'))
      end
    end

    context 'with invalid attributes' do
      let!(:log_to_update_val) { Fabricate(:assignment_log, action: 'VALID_ACTION', details: 'Initial details') }
      let(:invalid_update_attributes) { { details: nil } }

      before do
        AssignmentLog.plugin :validation_helpers
        AssignmentLog.class_eval do
          def validate
            super
            validates_presence :details
          end
        end
      end

      after do
        AssignmentLog.class_eval do
          def validate
            super
          end
        end
      end

      it 'does not update the log' do
        original_details = log_to_update_val.details
        expect do
          described_class.update(log_to_update_val.pk, invalid_update_attributes)
        rescue DAO::ValidationError
        end.not_to(change { log_to_update_val.refresh.details })
        expect(log_to_update_val.details).to eq(original_details)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.update(log_to_update_val.pk, invalid_update_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.errors).to have_key(:details)
        end
      end
    end

    context 'when the log does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.update(99_999, details: 'something')
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
      expect(described_class).to receive(:log_log_deleted).with(an_object_having_attributes(pk: log_id))
      described_class.delete(log_id)
    end

    context 'when the log does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.delete(99_999)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end

  describe '.find_by_assignment' do
    let!(:assignment) { Fabricate(:license_assignment) }
    let!(:log_a) { Fabricate(:assignment_log, assignment_id: assignment.pk, action: 'ASSIGNED') }
    let!(:log_b) { Fabricate(:assignment_log, assignment_id: assignment.pk, action: 'DEACTIVATED') }
    let!(:other_assignment) { Fabricate(:license_assignment) }
    let!(:other_log) { Fabricate(:assignment_log, assignment_id: other_assignment.pk) }

    it 'returns logs only for the specified assignment' do
      logs = described_class.find_by_assignment(assignment.pk)
      expect(logs.map(&:pk)).to match_array([log_a.pk, log_b.pk])
      expect(logs).not_to include(other_log)
    end

    it 'returns an empty array if assignment has no logs' do
      new_assignment = Fabricate(:license_assignment)
      logs = described_class.find_by_assignment(new_assignment.pk)
      expect(logs).to be_empty
    end
  end

  describe '.delete_by_assignment' do
    let!(:assignment) { Fabricate(:license_assignment) }
    let!(:log_a) { Fabricate(:assignment_log, assignment_id: assignment.pk) }
    let!(:log_b) { Fabricate(:assignment_log, assignment_id: assignment.pk) }
    let!(:other_assignment) { Fabricate(:license_assignment) }
    let!(:other_log) { Fabricate(:assignment_log, assignment_id: other_assignment.pk) }

    it 'deletes all logs for the given assignment and returns the count' do
      expect(AssignmentLog.where(assignment_id: assignment.pk).count).to eq(2)
      deleted_count = described_class.delete_by_assignment(assignment.pk)
      expect(deleted_count).to eq(2)
      expect(AssignmentLog.where(assignment_id: assignment.pk).count).to eq(0)
      expect(AssignmentLog[other_log.pk]).not_to be_nil
    end

    it 'returns 0 if no logs exist for the assignment' do
      new_assignment = Fabricate(:license_assignment)
      deleted_count = described_class.delete_by_assignment(new_assignment.pk)
      expect(deleted_count).to eq(0)
    end

    it 'logs the deletion' do
      allow(described_class).to receive(:log_logs_deleted_for_assignment)
      described_class.delete_by_assignment(assignment.pk)
      expect(described_class).to have_received(:log_logs_deleted_for_assignment).with(assignment.pk, 2)
    end
  end

  describe '.find_with_details' do
    let!(:user_a) { Fabricate(:user, username: 'UserA') }
    let!(:user_b) { Fabricate(:user, username: 'UserB') }
    let!(:prod_a) { Fabricate(:product, product_name: 'ProductA') }
    let!(:lic_a) { Fabricate(:license, product: prod_a, license_name: 'LicenseA') }
    let!(:assign_a1) { Fabricate(:license_assignment, user: user_a, license: lic_a) }
    let!(:assign_a2) { Fabricate(:license_assignment, user: user_a, license: lic_a) }
    let!(:assign_b1) { Fabricate(:license_assignment, user: user_b, license: lic_a) }

    let!(:time_now) { Time.now }
    let!(:time_yesterday) { time_now - (24 * 60 * 60) }
    let!(:time_two_days_ago) { time_now - (2 * 24 * 60 * 60) }

    let!(:log_a1_assign) do
      Fabricate(:assignment_log, assignment_id: assign_a1.pk, action: 'ASSIGNED', log_timestamp: time_yesterday)
    end
    let!(:log_a1_revoke) do
      Fabricate(:assignment_log, assignment_id: assign_a1.pk, action: 'REVOKED', log_timestamp: time_now)
    end
    let!(:log_a2_assign) do
      Fabricate(:assignment_log, assignment_id: assign_a2.pk, action: 'ASSIGNED', log_timestamp: time_two_days_ago)
    end
    let!(:log_b1_assign) do
      Fabricate(:assignment_log, assignment_id: assign_b1.pk, action: 'ASSIGNED', log_timestamp: time_yesterday)
    end

    context 'without filters' do
      it 'returns all logs paginated with details, ordered by timestamp descending', :aggregate_failures do
        result = described_class.find_with_details({}, { per_page: 2 })

        expect(result).to be_a(Hash)
        expect(result[:logs].count).to eq(2)
        expect(result[:logs][0].pk).to eq(log_a1_revoke.pk)
        expect(result[:logs][1].pk).to eq(log_b1_assign.pk)

        expect(result[:logs][0].associations).to have_key(:license_assignment)
        expect(result[:logs][0].license_assignment&.associations).to have_key(:user)
        expect(result[:logs][0].license_assignment&.associations).to have_key(:license)
        expect(result[:logs][0].license_assignment&.license&.associations).to have_key(:product)
        expect(result[:logs][0].license_assignment&.user&.username).to eq('UserA')
        expect(result[:logs][0].license_assignment&.license&.product&.product_name).to eq('ProductA')

        expect(result[:current_page]).to eq(1)
        expect(result[:total_pages]).to eq(2)
        expect(result[:total_entries]).to eq(4)
      end

      it 'fetches the second page correctly', :aggregate_failures do
        result = described_class.find_with_details({}, { page: 2, per_page: 2 })

        expect(result[:logs].count).to eq(2)
        expect(result[:logs].map(&:pk)).to include(log_a1_assign.pk, log_a2_assign.pk)

        expect(result[:current_page]).to eq(2)
        expect(result[:total_pages]).to eq(2)
        expect(result[:total_entries]).to eq(4)
      end

      it 'logs the info message' do
        expect(described_class).to receive(:log_info).with(/Fetched \d+ assignment logs/)
        described_class.find_with_details
      end
    end

    context 'with user filter' do
      it 'returns only logs related to the specified user' do
        result = described_class.find_with_details({ user_id: user_a.user_id })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to include(log_a1_assign.pk, log_a1_revoke.pk, log_a2_assign.pk)
        expect(log_pks).not_to include(log_b1_assign.pk)
        expect(result[:total_entries]).to eq(3)
      end

      it 'returns an empty set if user has no logs' do
        user_c = Fabricate(:user)
        result = described_class.find_with_details({ user_id: user_c.user_id })
        expect(result[:logs]).to be_empty
        expect(result[:total_entries]).to eq(0)
      end

      it 'handles invalid user id gracefully' do
        result = described_class.find_with_details({ user_id: 'invalid' })
        expect(result[:total_entries]).to eq(4)
        result_zero = described_class.find_with_details({ user_id: 0 })
        expect(result_zero[:total_entries]).to eq(4)
        result_nil = described_class.find_with_details({ user_id: nil })
        expect(result_nil[:total_entries]).to eq(4)
      end
    end

    context 'with action filter' do
      it 'returns only logs matching the action (case-insensitive)' do
        result = described_class.find_with_details({ action: ' assigned ' })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to include(log_a1_assign.pk, log_a2_assign.pk, log_b1_assign.pk)
        expect(log_pks).not_to include(log_a1_revoke.pk)
        expect(result[:total_entries]).to eq(3)
      end

      it 'returns logs partially matching the action' do
        result = described_class.find_with_details({ action: 'sign' })
        expect(result[:total_entries]).to eq(3)
      end

      it 'handles empty or nil action filter' do
        result = described_class.find_with_details({ action: ' ' })
        expect(result[:total_entries]).to eq(4)
        result_nil = described_class.find_with_details({ action: nil })
        expect(result_nil[:total_entries]).to eq(4)
      end
    end

    context 'with date filters' do
      it 'returns logs from a specific date onwards' do
        result = described_class.find_with_details({ date_from: time_yesterday.to_date })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to include(log_a1_revoke.pk, log_b1_assign.pk, log_a1_assign.pk)
        expect(log_pks).not_to include(log_a2_assign.pk)
        expect(result[:total_entries]).to eq(3)
      end

      it 'returns logs up to a specific date (inclusive)' do
        result = described_class.find_with_details({ date_to: time_yesterday.to_date })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to include(log_b1_assign.pk, log_a1_assign.pk, log_a2_assign.pk)
        expect(log_pks).not_to include(log_a1_revoke.pk)
        expect(result[:total_entries]).to eq(3)
      end

      it 'returns logs within a date range' do
        result = described_class.find_with_details({ date_from: time_yesterday.to_date,
                                                     date_to: time_yesterday.to_date })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to include(log_b1_assign.pk, log_a1_assign.pk)
        expect(log_pks).not_to include(log_a1_revoke.pk, log_a2_assign.pk)
        expect(result[:total_entries]).to eq(2)
      end

      it 'handles invalid date strings gracefully' do
        result = described_class.find_with_details({ date_from: 'invalid date' })
        expect(result[:total_entries]).to eq(4)
      end
    end

    context 'with combined filters' do
      it 'returns logs matching user and action' do
        result = described_class.find_with_details({ user_id: user_a.user_id, action: 'ASSIGNED' })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to include(log_a1_assign.pk, log_a2_assign.pk)
        expect(log_pks).not_to include(log_a1_revoke.pk, log_b1_assign.pk)
        expect(result[:total_entries]).to eq(2)
      end

      it 'returns logs matching user and date range' do
        result = described_class.find_with_details({ user_id: user_a.user_id, date_to: time_yesterday.to_date })
        log_pks = result[:logs].map(&:pk)

        expect(log_pks).to include(log_a1_assign.pk, log_a2_assign.pk)
        expect(log_pks).not_to include(log_a1_revoke.pk)
        expect(result[:total_entries]).to eq(2)
      end
    end
  end
end
