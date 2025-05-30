# frozen_string_literal: true

# Module for routes within profile context
module ProfileRoutes
  def self.registered(app)
    app.get '/profile' do
      require_login
      @title = 'Profile'
      @css   = 'profile'
      @user = current_user
      erb :'profile/show', layout: :'layouts/application'
    end

    app.post '/update_profile' do
      require_login
      content_type :json

      field = params[:field]
      value = params[:value]&.strip

      handle_profile_service_errors do
        ProfileService.update_profile(current_user, field, value)

        # Flash-Nachricht für erfolgreiche Updates
        case field
        when 'username'
          flash[:success] = 'Username updated successfully.'
        when 'email'
          flash[:success] = 'Email updated successfully.'
        when 'password'
          flash[:success] = 'Password updated successfully.'
        end

        # Dummy JSON response (wird durch Page Reload überschrieben)
        { success: true }.to_json
      end
    end

  end
end

