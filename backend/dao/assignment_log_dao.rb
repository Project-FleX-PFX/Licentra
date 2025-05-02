# frozen_string_literal: true

require_relative '../models/assignment_log'
require_relative 'base_dao'
require_relative 'assignment_log_logging'
require_relative 'assignment_log_error_handling'

# Basic DAO of the Assignment Log
class AssignmentLogDAO < BaseDAO
  class << self
    include AssignmentLogLogging
    include AssignmentLogErrorHandling

    MODEL_PK = :id

    # CREATE
    def create(attributes)
      context = 'creating assignment log'
      with_error_handling(context) do
        attributes[:log_timestamp] ||= Time.now
        log_entry = AssignmentLog.new(attributes)
        if log_entry.valid?
          log_entry.save_changes
          log_log_created(log_entry)
          log_entry
        else
          handle_validation_error(log_entry, context)
        end
      end
    end

    # READ

    def find!(id)
      with_error_handling("finding assignment log with ID #{id}") do
        log_entry = AssignmentLog[id]
        handle_record_not_found(id) unless log_entry
        log_log_found(log_entry)
        log_entry
      end
    end

    def find(id)
      with_error_handling("finding assignment log with ID #{id}") do
        log_entry = AssignmentLog[id]
        log_log_found(log_entry) if log_entry
        log_entry
      end
    end

    def find_one_by(criteria)
      with_error_handling('finding assignment log by criteria') do
        log_entry = AssignmentLog.first(criteria)
        log_log_found_by_criteria(criteria, log_entry) if log_entry
        log_entry
      end
    end

    def find_one_by!(criteria)
      with_error_handling('finding assignment log by criteria') do
        log_entry = find_one_by(criteria)
        handle_record_not_found_by_criteria(criteria) unless log_entry
        log_entry
      end
    end

    def all(options = {})
      with_error_handling('fetching all assignment logs') do
        dataset = AssignmentLog.dataset
        dataset = dataset.where(options[:where]) if options[:where]
        dataset = dataset.order(options[:order] || Sequel.desc(:log_timestamp))
        logs = dataset.all
        log_logs_fetched(logs.size)
        logs
      end
    end

    def where(criteria)
      with_error_handling('filtering assignment logs by criteria') do
        logs = AssignmentLog.where(criteria).order(Sequel.desc(:log_timestamp)).all
        log_logs_fetched_with_criteria(logs.size, criteria)
        logs
      end
    end

    # UPDATE
    def update(id, attributes)
      context = "updating assignment log with ID #{id}"
      with_error_handling(context) do
        attributes.delete(:assignment_id)
        attributes.delete(:log_timestamp)
        log_entry = find!(id)
        log_entry.update(attributes)
        log_log_updated(log_entry)
        log_entry
      rescue Sequel::ValidationFailed => e
        handle_validation_error(e.model, context)
      end
    end

    # DELETE
    def delete(id)
      with_error_handling("deleting assignment log with ID #{id}") do
        log_entry = find!(id)
        log_entry.destroy
        log_log_deleted(log_entry)
        true
      end
    end

    # --- SPECIAL QUERIES ---
    def find_by_assignment(assignment_id, options = {})
      context = "finding logs for assignment ID #{assignment_id}"
      with_error_handling(context) do
        logs = all(options.merge(where: { assignment_id: assignment_id }))
        log_logs_for_assignment_fetched(assignment_id, logs.size)
        logs
      end
    end

    def delete_by_assignment(assignment_id)
      context = "deleting logs for assignment ID #{assignment_id}"
      with_error_handling(context) do
        count = AssignmentLog.where(assignment_id: assignment_id).delete
        log_logs_deleted_for_assignment(assignment_id, count)
        count
      end
    end
  end
end
