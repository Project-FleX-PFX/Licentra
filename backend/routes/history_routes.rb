# frozen_string_literal: true

# Module for routes within history context
module HistoryRoutes
  def self.registered(app) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    app.get '/history' do
      require_login

      @active_tab = params[:active_tab] || 'assignments'

      @all_users = UserDAO.all(order: :username)

      @assignment_filter_params = {
        user_id: params[:assignment_user_id_filter]&.to_i,
        license_id: params[:assignment_license_id_filter]&.to_i,
        action: params[:assignment_action_filter],
        details_contains: params[:assignment_details_filter],
        date_from: params[:assignment_date_from_filter],
        date_to: params[:assignment_date_to_filter]
      }
      assignment_filters = {}
      assignment_options = { page: params[:assignment_page] || 1, per_page: 15 }

      if current_user.admin?
        if @assignment_filter_params[:user_id]&.positive?
          assignment_filters[:user_id] =
            @assignment_filter_params[:user_id]
        end
      else
        assignment_filters[:user_id] = current_user.user_id
        @assignment_filter_params[:user_id] = current_user.user_id
      end

      if @assignment_filter_params[:license_id]&.positive?
        assignment_filters[:license_id] =
          @assignment_filter_params[:license_id]
      end

      if @assignment_filter_params[:action] && !@assignment_filter_params[:action].to_s.strip.empty?
        assignment_filters[:action] = @assignment_filter_params[:action]
      end
      if @assignment_filter_params[:details_contains] && !@assignment_filter_params[:details_contains].to_s.strip.empty?
        assignment_filters[:details_contains] = @assignment_filter_params[:details_contains]
      end
      if @assignment_filter_params[:date_from] && !@assignment_filter_params[:date_from].to_s.strip.empty?
        assignment_filters[:date_from] = @assignment_filter_params[:date_from]
      end
      if @assignment_filter_params[:date_to] && !@assignment_filter_params[:date_to].to_s.strip.empty?
        assignment_filters[:date_to] = @assignment_filter_params[:date_to]
      end

      @assignment_actions = AssignmentLogDAO.distinct_actions
      @all_licenses = LicenseDAO.all(order: :license_name)

      assignment_result = AssignmentLogDAO.find_with_details(assignment_filters, assignment_options)
      @assignment_logs_data = assignment_result

      @security_filter_params = {
        user_id: params[:security_user_id_filter]&.to_i,
        action: params[:security_action_filter],
        object: params[:security_object_filter],
        details_contains: params[:security_details_filter],
        date_from: params[:security_date_from_filter],
        date_to: params[:security_date_to_filter]
      }
      security_filters = {}
      security_options = { page: params[:security_page] || 1, per_page: 15 }

      if current_user.admin?
        security_filters[:user_id] = @security_filter_params[:user_id] if @security_filter_params[:user_id]&.positive?
      else
        security_filters[:user_id] = current_user.user_id
        @security_filter_params[:user_id] = current_user.user_id
      end

      if @security_filter_params[:action] && !@security_filter_params[:action].to_s.strip.empty?
        security_filters[:action] = @security_filter_params[:action]
      end
      if @security_filter_params[:object] && !@security_filter_params[:object].to_s.strip.empty?
        security_filters[:object] = @security_filter_params[:object]
      end
      if @security_filter_params[:details_contains] && !@security_filter_params[:details_contains].to_s.strip.empty?
        security_filters[:details_contains] = @security_filter_params[:details_contains]
      end
      if @security_filter_params[:date_from] && !@security_filter_params[:date_from].to_s.strip.empty?
        security_filters[:date_from] = @security_filter_params[:date_from]
      end
      if @security_filter_params[:date_to] && !@security_filter_params[:date_to].to_s.strip.empty?
        security_filters[:date_to] = @security_filter_params[:date_to]
      end

      @security_actions = SecurityLogDAO.distinct_actions
      @security_objects = SecurityLogDAO.distinct_objects

      security_result = SecurityLogDAO.find_with_details(security_filters, security_options)
      @security_logs_data = security_result

      @title = 'History Logs'
      @css = 'history'
      erb :'history/index', layout: :'layouts/application'
    end
  end
end
