module RoutesErrorHelpers
  def format_creation_error(error)
    error_messages_array = error.errors.full_messages

    if error_messages_array.any?
      formatted_error_string = format_error_message(error_messages_array)
      flash[:error] = "User creation failed due to validation errors:#{formatted_error_string}"
    else
      flash[:error] = "User creation failed due to validation errors. Please check your input"
    end
  end

  def format_update_error(error)
    error_messages_array = error.errors.full_messages

    if error_messages_array.any?
      formatted_error_string = format_error_message(error_messages_array)
      flash[:error] = "Updating user failed due to validation errors:#{formatted_error_string}"
    else
      flash[:error] = "Updating user failed due to validation errors. Please check your input"
    end
  end

  def format_error_message(error_messages_array)
    error_messages_array.map.with_index do |message, index|
      if index == 0
        " " + message
      else
        ", " + message
      end
    end.join
  end
end