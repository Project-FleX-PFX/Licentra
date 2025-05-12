# frozen_string_literal: true

# Module for routes within history context
module HistoryRoutes
  def self.registered(app)
    app.get '/history' do
      require_login

      @filter_user_id = params[:user_id_filter]&.to_i
      @all_users = []

      filters = {}
      options = { page: params[:page] || 1, per_page: 20 }

      if current_user.admin?
        @all_users = UserDAO.all(order: :username)
        filters[:user_id] = @filter_user_id if @filter_user_id&.positive?
      else
        filters[:user_id] = current_user.user_id
        @filter_user_id = current_user.user_id
      end

      filters[:action] = params[:action_filter] if params[:action_filter]

      result = AssignmentLogDAO.find_with_details(filters, options)
      @assignment_logs = result[:logs]
      @current_page = result[:current_page]
      @total_pages = result[:total_pages]
      @total_entries = result[:total_entries]

      @title = 'License Assignment History'
      @css = 'history'
      erb :'history/index'
    end
  end
end
