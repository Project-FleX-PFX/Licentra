# frozen_string_literal: true

# Module for routes within profile context
module ProfileRoutes
  def self.registered(app)
    app.get '/profile' do
      require_login
      @title = 'Profile'
      @css   = 'profile'
      @user = current_user
      erb :profile
    end

    app.post '/update_profile' do
      require_login
      content_type :json

      field = params[:field]
      value = params[:value]

      allowed_fields = %w[username email password]
      return { success: false, message: 'Invalid field' }.to_json unless allowed_fields.include?(field)

      begin
        result = ProfileService.update_profile(current_user, field, value)
        result.to_json
      rescue StandardError => e
        { success: false, message: e.message }.to_json
      end
    end
  end
end
