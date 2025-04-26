# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AssignmentLogDAO do
  let(:license_assignment) { Fabricate(:license_assignment) }
  let(:valid_attributes) do
    Fabricate.attributes_for(:assignment_log, assignment_id: license_assignment.pk)
  end
  let!(:log1) { Fabricate(:assignment_log, assignment_id: license_assignment.pk, action: 'ASSIGNED') }
  let!(:log2) { Fabricate(:assignment_log, assignment_id: license_assignment.pk, action: 'ACTIVATED') }

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
        expect(log.assignment_id).to eq(license_assignment.pk)
        expect(log.action).to eq(valid_attributes[:action])
        expect(log.pk).not_to be_nil
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
        rescue StandardError
          # Erwarteter Fehler
        end.not_to change(AssignmentLog, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating assignment log/i)
          expect(error.errors).to have_key(:action)
        end
      end

      it 'logs the validation failure' do
        allow(described_class).to receive(:log_validation_failed)
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError)
        expect(described_class).to have_received(:log_validation_failed).with(an_instance_of(AssignmentLog),
                                                                              /creating assignment log/i)
      end
    end
  end

  describe '.find!' do
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
    it 'returns the log object if it exists' do
      expect(described_class.find(log1.pk)).to eq(log1)
    end

    it 'returns nil if the log does not exist' do
      expect(described_class.find(99_999)).to be_nil
    end
  end

  describe '.all' do
    before do
      AssignmentLog.dataset.delete
      Fabricate(:assignment_log, action: 'ASSIGNED')
      Fabricate(:assignment_log, action: 'DEACTIVATED')
    end

    it 'returns all existing logs', :aggregate_failures do
      logs = described_class.all
      expect(logs.count).to eq(4)
      expect(logs.map(&:action)).to match_array(%w[ASSIGNED ASSIGNED ASSIGNED DEACTIVATED])
    end

    it 'logs the fetch operation' do
      allow(described_class).to receive(:log_logs_fetched)
      described_class.all
      expect(described_class).to have_received(:log_logs_fetched).with(4)
    end
  end

  describe '.update' do
    let!(:log_to_update) { Fabricate(:assignment_log, action: 'ASSIGNED') }
    let(:update_attributes) { { action: 'DEACTIVATED' } }

    context 'with valid attributes' do
      it 'updates the log attributes', :aggregate_failures do
        updated_log = described_class.update(log_to_update.pk, update_attributes)
        log_to_update.refresh
        expect(log_to_update.action).to eq('DEACTIVATED')
        expect(updated_log.action).to eq('DEACTIVATED')
      end

      it 'logs the update' do
        allow(described_class).to receive(:log_log_updated)
        described_class.update(log_to_update.pk, update_attributes)
        expect(described_class).to have_received(:log_log_updated).with(log_to_update)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_update_attributes) { { action: nil } }

      it 'does not update the log' do
        expect do
          described_class.update(log_to_update.pk, invalid_update_attributes)
        rescue StandardError
          # Erwarteter Fehler
        end.not_to(change { log_to_update.refresh.action })
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.update(log_to_update.pk, invalid_update_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.errors).to have_key(:action)
        end
      end

      it 'logs the validation failure' do
        allow(described_class).to receive(:log_validation_failed)
        expect do
          described_class.update(log_to_update.pk, invalid_update_attributes)
        end.to raise_error(DAO::ValidationError)
        expect(described_class).to have_received(:log_validation_failed).with(an_instance_of(AssignmentLog),
                                                                              /updating assignment log/i)
      end
    end

    context 'when the log does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.update(99_999, action: 'something')
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
      allow(described_class).to receive(:log_log_deleted)
      described_class.delete(log_id)
      expect(described_class).to have_received(:log_log_deleted).with(log_to_delete)
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
    let!(:other_log) { Fabricate(:assignment_log) }

    it 'returns logs for the specified assignment' do
      logs = described_class.find_by_assignment(assignment.pk)
      expect(logs).to include(log_a, log_b)
      expect(logs).not_to include(other_log)
    end
  end

  describe '.delete_by_assignment' do
    let!(:assignment) { Fabricate(:license_assignment) }
    let!(:log_a) { Fabricate(:assignment_log, assignment_id: assignment.pk) }
    let!(:log_b) { Fabricate(:assignment_log, assignment_id: assignment.pk) }
    let!(:other_log) { Fabricate(:assignment_log) }

    it 'deletes all logs for the given assignment' do
      expect do
        described_class.delete_by_assignment(assignment.pk)
      end.to change { AssignmentLog.where(assignment_id: assignment.pk).count }.from(3).to(0)
      expect(AssignmentLog[other_log.pk]).not_to be_nil
    end
  end
end
