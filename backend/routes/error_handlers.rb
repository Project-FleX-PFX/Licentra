# frozen_string_literal: true

module ErrorHandlers
  def self.registered(app)
    # Helper-Methode zur Erkennung von API-Anfragen
    app.helpers do
      def api_request?
        request.path.start_with?('/api/') ||
          request.accept.include?('application/json') ||
          request.path.end_with?('.json') ||
          request.env['HTTP_ACCEPT']&.include?('application/json') ||
          content_type&.include?('application/json')
      end
    end

    # 404 Error - Page Not Found
    app.not_found do
      if api_request?
        content_type :json
        status 404
        { error: 'Resource not found', status: 404 }.to_json
      else
        @title = '404 - Page Not Found | Licentra'
        erb :'errors/404', layout: :'layouts/error', locals: { message: 'The requested page could not be found.' }
      end
    end

    # 401 Error - Unauthorized
    app.error 401 do
      message = env['sinatra.error']&.message || 'Authentication required to access this resource.'

      if api_request?
        content_type :json
        status 401
        { error: message, status: 401 }.to_json
      else
        @title = '401 - Unauthorized | Licentra'
        erb :'errors/401', layout: :'layouts/error', locals: { message: message }
      end
    end

    # 403 Error - Access Denied
    app.error 403 do
      message = env['sinatra.error']&.message || "You don't have sufficient permissions to access this resource."

      if api_request?
        content_type :json
        status 403
        { error: message, status: 403 }.to_json
      else
        @title = '403 - Access Denied | Licentra'
        erb :'errors/403', layout: :'layouts/error', locals: { message: message }
      end
    end

    # 422 Error - Unprocessable Entity
    app.error 422 do
      message = env['sinatra.error']&.message || 'The request was well-formed but contains semantic errors.'

      if api_request?
        content_type :json
        status 422
        { error: message, status: 422 }.to_json
      else
        @title = '422 - Unprocessable Entity | Licentra'
        erb :'errors/422', layout: :'layouts/error', locals: { message: message }
      end
    end

    # 429 Error - Too Many Requests
    app.error 429 do
      message = env['sinatra.error']&.message || 'You have sent too many requests in a given amount of time.'

      if api_request?
        content_type :json
        status 429
        { error: message, status: 429 }.to_json
      else
        @title = '429 - Too Many Requests | Licentra'
        erb :'errors/429', layout: :'layouts/error', locals: { message: message }
      end
    end

    # 500 Error - Internal Server Error
    app.error 500 do
      message = env['sinatra.error']&.message || 'An internal server error has occurred.'
      app.settings.production? && request.logger.error("500 Error: #{env['sinatra.error'].message}\n#{env['sinatra.error'].backtrace.join("\n")}")

      if api_request?
        content_type :json
        status 500
        { error: message, status: 500 }.to_json
      else
        @title = '500 - Internal Server Error | Licentra'
        erb :'errors/500', layout: :'layouts/error', locals: { message: message }
      end
    end

    # General error handler for all other errors
    app.error do
      # Make sure we set a 500 status if not already set
      status 500 unless (400..599).cover?(response.status)

      message = env['sinatra.error']&.message || 'An unexpected error has occurred.'
      app.settings.production? && request.logger.error("Generic Error: #{env['sinatra.error'].message}\n#{env['sinatra.error'].backtrace.join("\n")}")

      if api_request?
        content_type :json
        { error: message, status: response.status }.to_json
      else
        @title = 'Error | Licentra'
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
end
