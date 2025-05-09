# frozen_string_literal: true

# General helper methods
module ApplicationHelpers
  def flash
    request.env['x-rack.flash']
  end

  def render_flash_messages
    return '' unless flash && !flash.empty?

    messages_html = '<div id="flash-messages">'
    flash.each do |type, message|
      escaped_message = Rack::Utils.escape_html(message)
      messages_html += "<div class=\"alert alert-#{Rack::Utils.escape_html(type)}\">#{escaped_message}</div>"
    end
    messages_html += '</div>'
    messages_html
  end

  def format_date(date)
    date&.strftime('%d.%m.%Y')
  end

  def current_page?(path)
    request.path_info == path
  end
end
