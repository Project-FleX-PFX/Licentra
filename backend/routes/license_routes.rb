# frozen_string_literal: true

# Module for routes within license context
module LicenseRoutes
  def self.registered(app)
    app.get '/license' do
      require_login
      @title = 'License'
      @css   = 'license'
      erb :license
    end

    app.get '/my_license' do
      require_login
      @title = 'My License'
      @css   = 'my_license'
      erb :my_license
    end
  end
end
