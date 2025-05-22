# frozen_string_literal: true

module ErrorHandlers
  def self.registered(app)
    # 404 Error - Page Not Found
    app.not_found do
      @title = "404 - Page Not Found | Licentra"
      erb :'errors/404', layout: :'layouts/error', locals: { message: "The requested page could not be found." }
    end

    # 403 Error - Access Denied
    app.error 403 do
      @title = "403 - Access Denied | Licentra"
      message = env['sinatra.error']&.message || "You don't have sufficient permissions to access this resource."
      erb :'errors/403', layout: :'layouts/error', locals: { message: message }
    end

    # 500 Error - Internal Server Error
    app.error 500 do
      @title = "500 - Internal Server Error | Licentra"
      message = env['sinatra.error']&.message || "An internal server error has occurred."
      app.settings.production? && request.logger.error("500 Error: #{env['sinatra.error'].message}\n#{env['sinatra.error'].backtrace.join("\n")}")
      erb :'errors/500', layout: :'layouts/error', locals: { message: message }
    end

    # General error handler for all other errors
    app.error do
      @title = "Error | Licentra"
      # Make sure we set a 500 status if not already set
      unless (400..599).cover?(response.status)
        status 500
      end
      
      message = env['sinatra.error']&.message || "An unexpected error has occurred."
      app.settings.production? && request.logger.error("Generic Error: #{env['sinatra.error'].message}\n#{env['sinatra.error'].backtrace.join("\n")}")
      
      template_name = "errors/#{response.status}".to_sym
      template_path = File.join(app.settings.views, "#{template_name}.erb")

      if File.exist?(template_path) && (400..599).cover?(response.status)
        erb template_name, layout: :'layouts/error', locals: { message: message }
      else
        erb :'errors/500', layout: :'layouts/error', locals: { message: message }
      end
    end
  end
end

