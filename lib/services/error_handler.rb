# ErrorHandler provides centralized error handling utilities for the Bandmate application.
#
# This service standardizes error handling across different contexts:
# - HTML form error display
# - JSON API error responses
# - Exception handling and logging
# - Success response formatting
#
# The service promotes consistent error messaging and reduces code duplication
# across controllers and views.
#
# @example Basic usage in a controller
#   if model.save
#     redirect_to success_path
#   else
#     ErrorHandler.setup_form_errors(model, self)
#     render :form_template
#   end
#
# @example JSON API error handling
#   error_response = ErrorHandler.handle_json_errors(model)
#   if error_response
#     render json: error_response, status: :unprocessable_entity
#   else
#     render json: ErrorHandler.success_response(data: model)
#   end
class ErrorHandler
  # Sets up form error display for HTML views by configuring instance variables.
  #
  # This method standardizes error handling for HTML forms by setting the @errors
  # instance variable that view partials expect. It should be used in controller
  # actions that render forms with validation errors.
  #
  # @param model [ActiveRecord::Base, ActiveModel::Model] Model with potential validation errors
  # @param view_context [Object] Controller or view context where @errors should be set
  # @return [Boolean] true if errors were found and set, false if no errors
  #
  # @example In a controller action
  #   def create
  #     @user = User.new(user_params)
  #     if @user.save
  #       redirect_to @user
  #     else
  #       ErrorHandler.setup_form_errors(@user, self)
  #       render :new
  #     end
  #   end
  def self.setup_form_errors(model, view_context)
    if model.errors.any?
      view_context.instance_variable_set(:@errors, model.errors.full_messages)
      true
    else
      false
    end
  end

  # Creates standardized JSON error responses for API endpoints.
  #
  # Returns a structured error hash when the model has validation errors,
  # or false when the model is valid. This provides consistent API error formatting.
  #
  # @param model [ActiveRecord::Base, ActiveModel::Model] Model to check for errors
  # @return [Hash, false] Error hash with success, errors, and details keys, or false if valid
  #
  # @example API controller usage
  #   error_response = ErrorHandler.handle_json_errors(@user)
  #   if error_response
  #     render json: error_response, status: :unprocessable_entity
  #   else
  #     render json: { success: true, data: @user }
  #   end
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

  # Generic exception handling for rescue blocks with format-specific responses.
  #
  # Provides consistent exception handling that can return either HTML-friendly
  # error messages or structured JSON error responses.
  #
  # @param exception [Exception] The exception that was caught
  # @param format [Symbol] Response format (:html or :json)
  # @return [String, Hash] Formatted error message or JSON error hash
  #
  # @example HTML error handling
  #   begin
  #     risky_operation
  #   rescue => e
  #     @error = ErrorHandler.handle_exception(e, format: :html)
  #   end
  #
  # @example JSON error handling
  #   begin
  #     risky_operation
  #   rescue => e
  #     render json: ErrorHandler.handle_exception(e, format: :json)
  #   end
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

  # Creates structured validation error responses with optional metadata.
  #
  # @param model [ActiveRecord::Base, ActiveModel::Model] Model with validation errors
  # @param redirect_to [String] Optional redirect URL for the response
  # @param status [Integer] HTTP status code (default: 422 Unprocessable Entity)
  # @return [Hash] Structured error response with errors, redirect, and status
  #
  # @example
  #   response = ErrorHandler.validation_error_response(@user, redirect_to: '/users', status: 400)
  def self.validation_error_response(model, redirect_to: nil, status: 422)
    {
      errors: model.errors.full_messages,
      redirect_to: redirect_to,
      status: status
    }
  end

  # Creates standardized success responses for API endpoints.
  #
  # Provides consistent success response formatting with optional message,
  # data payload, and redirect information.
  #
  # @param message [String] Optional success message
  # @param data [Object] Optional data payload to include in response
  # @param redirect_to [String] Optional redirect URL
  # @return [Hash] Success response hash
  #
  # @example Basic success
  #   ErrorHandler.success_response
  #   # => { success: true }
  #
  # @example Success with data
  #   ErrorHandler.success_response(message: "Created!", data: @user, redirect_to: "/users")
  #   # => { success: true, message: "Created!", data: @user, redirect_to: "/users" }
  def self.success_response(message: nil, data: nil, redirect_to: nil)
    response = { success: true }
    response[:message] = message if message
    response[:data] = data if data
    response[:redirect_to] = redirect_to if redirect_to
    response
  end

  # Helper method to check if a model has validation errors.
  #
  # Safely checks if an object responds to the errors method and has any errors,
  # without raising exceptions for objects that don't support ActiveModel validations.
  #
  # @param model [Object] Object to check for errors
  # @return [Boolean] true if the model has validation errors, false otherwise
  #
  # @example
  #   ErrorHandler.has_errors?(@user)     # => true/false
  #   ErrorHandler.has_errors?(nil)       # => false
  #   ErrorHandler.has_errors?("string")  # => false
  def self.has_errors?(model)
    model.respond_to?(:errors) && model.errors.any?
  end

  # Formats various error types into a consistent array format for display.
  #
  # Handles different error input types and normalizes them into an array of
  # user-friendly error messages suitable for display in views or APIs.
  #
  # @param errors [ActiveModel::Errors, Array, String, Object] Errors to format
  # @return [Array<String>] Array of formatted error messages
  #
  # @example Different input types
  #   ErrorHandler.format_errors(@user.errors)           # => ["Name is required", "Email is invalid"]
  #   ErrorHandler.format_errors(["Custom error"])       # => ["Custom error"]
  #   ErrorHandler.format_errors("Single error")         # => ["Single error"]
  #   ErrorHandler.format_errors(nil)                    # => []
  #   ErrorHandler.format_errors({ unknown: "type" })    # => ["An unexpected error occurred"]
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

  # Logs exception details and returns a user-friendly error message.
  #
  # Provides centralized exception logging with optional context information.
  # Logs the full exception details for debugging while returning a safe,
  # user-friendly message for display.
  #
  # @param exception [Exception] The exception to log and handle
  # @param context [String] Optional context description for the error
  # @param user_message [String] User-friendly message to return (default: "An error occurred")
  # @return [String] User-friendly error message
  #
  # @example Basic usage
  #   begin
  #     risky_operation
  #   rescue => e
  #     message = ErrorHandler.log_and_respond(e, context: "User creation")
  #     flash[:error] = message
  #   end
  #
  # @example Custom user message
  #   ErrorHandler.log_and_respond(exception,
  #     context: "Payment processing",
  #     user_message: "Payment failed. Please try again."
  #   )
  def self.log_and_respond(exception, context: nil, user_message: "An error occurred")
    # In a real app, you'd log to your logging system here
    puts "[ERROR] #{context}: #{exception.message}" if context
    puts "[ERROR] #{exception.message}" unless context
    puts exception.backtrace.first(5).join("\n") if exception.backtrace

    user_message
  end
end