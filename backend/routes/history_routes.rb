# frozen_string_literal: true

# Module for routes within history context
module HistoryRoutes
  def self.registered(app) # rubocop:disable Metrics/AbcSize
    app.get '/history' do
      require_login

      @active_tab = params[:active_tab] || 'assignments'
      @all_users_for_filter = UserDAO.all(order: :username)

      prepare_filter_options

      @assignment_filter_params, assignment_filters = collect_assignment_log_filters(params, current_user)
      assignment_options = { page: params[:assignment_page] || 1, per_page: 15 }
      @assignment_logs_data = AssignmentLogDAO.find_with_details(assignment_filters, assignment_options)

      @security_filter_params, security_filters = collect_security_log_filters(params, current_user)
      security_options = { page: params[:security_page] || 1, per_page: 15 }
      @security_logs_data = SecurityLogDAO.find_with_details(security_filters, security_options)

      @title = 'History Logs'
      @css = 'history'
      erb :'history/index', layout: :'layouts/application'
    end

    app.helpers do # rubocop:disable Metrics/BlockLength
      def prepare_filter_options
        if current_user.admin?
          @all_licenses_for_filter = AssignmentLogDAO.find_unique_license_info
          @assignment_actions_for_filter = AssignmentLogDAO.distinct_actions
          @security_objects_for_filter = SecurityLogDAO.distinct_objects
          @security_actions_for_filter = SecurityLogDAO.distinct_actions
        else
          @all_licenses_for_filter = AssignmentLogDAO.find_unique_license_info_for_user_logs(current_user.user_id)
          @assignment_actions_for_filter = [
            AssignmentLogDAO::Actions::USER_ACTIVATED,
            AssignmentLogDAO::Actions::USER_DEACTIVATED
          ].sort
          @security_objects_for_filter = [
            SecurityLogDAO::Objects::USER_ACCOUNT,
            SecurityLogDAO::Objects::USER_SESSION
          ].sort
          @security_actions_for_filter = [
            SecurityLogDAO::Actions::LOGIN_SUCCESS,
            SecurityLogDAO::Actions::LOGIN_FAILURE,
            SecurityLogDAO::Actions::PASSWORD_RESET_REQUEST,
            SecurityLogDAO::Actions::PASSWORD_CHANGED
          ].sort
        end
      end

      def collect_assignment_log_filters(params, current_user)
        filter_params = {
          user_id: params[:assignment_user_id_filter]&.to_i,
          license_id: params[:assignment_license_id_filter]&.to_i,
          action: params[:assignment_action_filter],
          details_contains: params[:assignment_details_filter],
          date_from: params[:assignment_date_from_filter],
          date_to: params[:assignment_date_to_filter]
        }

        filters = {}
        if current_user.admin?
          filters[:user_id] = filter_params[:user_id] if filter_params[:user_id]&.positive?
        else
          filters[:user_id] = current_user.user_id
          filter_params[:user_id] = current_user.user_id
        end

        filters[:license_id] = filter_params[:license_id] if filter_params[:license_id]&.positive?

        action_value = filter_params[:action]
        filters[:action] = action_value if action_value && !action_value.strip.empty?

        details_value = filter_params[:details_contains]
        filters[:details_contains] = details_value if details_value && !details_value.strip.empty?

        date_from_value = filter_params[:date_from]
        filters[:date_from] = date_from_value if date_from_value && !date_from_value.strip.empty?

        date_to_value = filter_params[:date_to]
        filters[:date_to] = date_to_value if date_to_value && !date_to_value.strip.empty?

        [filter_params, filters]
      end

      def collect_security_log_filters(params, current_user)
        filter_params = {
          user_id: params[:security_user_id_filter]&.to_i,
          action: params[:security_action_filter],
          object: params[:security_object_filter],
          details_contains: params[:security_details_filter],
          date_from: params[:security_date_from_filter],
          date_to: params[:security_date_to_filter]
        }

        filters = {}
        if current_user.admin?
          filters[:user_id] = filter_params[:user_id] if filter_params[:user_id]&.positive?
        else
          filters[:user_id] = current_user.user_id
          filter_params[:user_id] = current_user.user_id
        end

        action_value = filter_params[:action]
        filters[:action] = action_value if action_value && !action_value.strip.empty?

        object_value = filter_params[:object]
        filters[:object] = object_value if object_value && !object_value.strip.empty?

        details_value = filter_params[:details_contains]
        filters[:details_contains] = details_value if details_value && !details_value.strip.empty?

        date_from_value = filter_params[:date_from]
        filters[:date_from] = date_from_value if date_from_value && !date_from_value.strip.empty?

        date_to_value = filter_params[:date_to]
        filters[:date_to] = date_to_value if date_to_value && !date_to_value.strip.empty?

        [filter_params, filters]
      end
    end
  end
end
