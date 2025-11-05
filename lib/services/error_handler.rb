class ErrorHandler
  # Standardized error response for HTML forms - sets up instance variables
  def self.setup_form_errors(model, view_context)
    if model.errors.any?
      view_context.instance_variable_set(:@errors, model.errors.full_messages)
      true
    else
      false
    end
  end

  # Standardized error response for JSON API endpoints
  def self.handle_json_errors(model)
    if model.errors.any?
      {
        success: false,
        errors: model.errors.full_messages,
        details: model.errors.messages
      }
    else
      false
    end
  end

  # Generic error handling for rescue blocks
  def self.handle_exception(exception, format: :html)
    case format
    when :json
      {
        success: false,
        error: exception.message,
        type: exception.class.name
      }
    when :html
      "An error occurred: #{exception.message}"
    end
  end

  # Consistent error display for validation failures
  def self.validation_error_response(model, redirect_to: nil, status: 422)
    {
      errors: model.errors.full_messages,
      redirect_to: redirect_to,
      status: status
    }
  end

  # Standardized success response
  def self.success_response(message: nil, data: nil, redirect_to: nil)
    response = { success: true }
    response[:message] = message if message
    response[:data] = data if data
    response[:redirect_to] = redirect_to if redirect_to
    response
  end

  # Helper to check if a model has validation errors
  def self.has_errors?(model)
    model.respond_to?(:errors) && model.errors.any?
  end

  # Format errors for display
  def self.format_errors(errors)
    return [] unless errors

    case errors
    when ActiveModel::Errors
      errors.full_messages
    when Array
      errors
    when String
      [errors]
    else
      ["An unexpected error occurred"]
    end
  end

  # Log and return user-friendly error message
  def self.log_and_respond(exception, context: nil, user_message: "An error occurred")
    # In a real app, you'd log to your logging system here
    puts "[ERROR] #{context}: #{exception.message}" if context
    puts "[ERROR] #{exception.message}" unless context
    puts exception.backtrace.first(5).join("\n") if exception.backtrace

    user_message
  end
end