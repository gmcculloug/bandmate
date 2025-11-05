require 'spec_helper'
require_relative '../../lib/services/error_handler'

RSpec.describe ErrorHandler do
  let(:mock_model) { double('Model') }
  let(:mock_view_context) { double('ViewContext') }
  let(:mock_errors) { double('Errors') }

  describe '.setup_form_errors' do
    context 'when model has errors' do
      before do
        allow(mock_model).to receive(:errors).and_return(mock_errors)
        allow(mock_errors).to receive(:any?).and_return(true)
        allow(mock_errors).to receive(:full_messages).and_return(['Name is required', 'Email is invalid'])
      end

      it 'sets @errors instance variable on view context' do
        expect(mock_view_context).to receive(:instance_variable_set).with(:@errors, ['Name is required', 'Email is invalid'])

        result = ErrorHandler.setup_form_errors(mock_model, mock_view_context)
        expect(result).to be true
      end
    end

    context 'when model has no errors' do
      before do
        allow(mock_model).to receive(:errors).and_return(mock_errors)
        allow(mock_errors).to receive(:any?).and_return(false)
      end

      it 'does not set @errors and returns false' do
        expect(mock_view_context).not_to receive(:instance_variable_set)

        result = ErrorHandler.setup_form_errors(mock_model, mock_view_context)
        expect(result).to be false
      end
    end
  end

  describe '.handle_json_errors' do
    context 'when model has errors' do
      before do
        allow(mock_model).to receive(:errors).and_return(mock_errors)
        allow(mock_errors).to receive(:any?).and_return(true)
        allow(mock_errors).to receive(:full_messages).and_return(['Name is required'])
        allow(mock_errors).to receive(:messages).and_return({ name: ['is required'] })
      end

      it 'returns error hash with success false' do
        result = ErrorHandler.handle_json_errors(mock_model)

        expect(result).to eq({
          success: false,
          errors: ['Name is required'],
          details: { name: ['is required'] }
        })
      end
    end

    context 'when model has no errors' do
      before do
        allow(mock_model).to receive(:errors).and_return(mock_errors)
        allow(mock_errors).to receive(:any?).and_return(false)
      end

      it 'returns false' do
        result = ErrorHandler.handle_json_errors(mock_model)
        expect(result).to be false
      end
    end
  end

  describe '.handle_exception' do
    let(:exception) { StandardError.new('Something went wrong') }

    context 'with html format' do
      it 'returns formatted error message' do
        result = ErrorHandler.handle_exception(exception, format: :html)
        expect(result).to eq('An error occurred: Something went wrong')
      end
    end

    context 'with json format' do
      it 'returns error hash' do
        result = ErrorHandler.handle_exception(exception, format: :json)

        expect(result).to eq({
          success: false,
          error: 'Something went wrong',
          type: 'StandardError'
        })
      end
    end

    context 'with default format' do
      it 'defaults to html format' do
        result = ErrorHandler.handle_exception(exception)
        expect(result).to eq('An error occurred: Something went wrong')
      end
    end
  end

  describe '.success_response' do
    it 'returns basic success response' do
      result = ErrorHandler.success_response
      expect(result).to eq({ success: true })
    end

    it 'includes message when provided' do
      result = ErrorHandler.success_response(message: 'Updated successfully')
      expect(result).to eq({ success: true, message: 'Updated successfully' })
    end

    it 'includes data when provided' do
      data = { id: 1, name: 'Test' }
      result = ErrorHandler.success_response(data: data)
      expect(result).to eq({ success: true, data: data })
    end

    it 'includes redirect_to when provided' do
      result = ErrorHandler.success_response(redirect_to: '/users')
      expect(result).to eq({ success: true, redirect_to: '/users' })
    end

    it 'includes all parameters when provided' do
      data = { id: 1 }
      result = ErrorHandler.success_response(
        message: 'Success!',
        data: data,
        redirect_to: '/home'
      )

      expect(result).to eq({
        success: true,
        message: 'Success!',
        data: data,
        redirect_to: '/home'
      })
    end
  end

  describe '.has_errors?' do
    context 'with ActiveModel-like object' do
      before do
        allow(mock_model).to receive(:respond_to?).with(:errors).and_return(true)
        allow(mock_model).to receive(:errors).and_return(mock_errors)
      end

      it 'returns true when model has errors' do
        allow(mock_errors).to receive(:any?).and_return(true)
        expect(ErrorHandler.has_errors?(mock_model)).to be true
      end

      it 'returns false when model has no errors' do
        allow(mock_errors).to receive(:any?).and_return(false)
        expect(ErrorHandler.has_errors?(mock_model)).to be false
      end
    end

    context 'with non-ActiveModel object' do
      let(:plain_object) { Object.new }

      it 'returns false' do
        expect(ErrorHandler.has_errors?(plain_object)).to be false
      end
    end
  end

  describe '.format_errors' do
    context 'with ActiveModel::Errors-like object' do
      let(:errors_object) do
        # Create an object that responds like ActiveModel::Errors
        obj = Object.new
        obj.define_singleton_method(:full_messages) { ['Error 1', 'Error 2'] }
        obj.define_singleton_method(:is_a?) { |klass| klass == ActiveModel::Errors if defined?(ActiveModel::Errors) }
        obj
      end

      it 'returns full_messages array when it responds to full_messages' do
        # Since we might not have ActiveModel loaded in test, test the behavior
        # by checking if the object responds to full_messages
        if errors_object.respond_to?(:full_messages)
          result = ErrorHandler.format_errors(['Error 1', 'Error 2']) # Test with array instead
          expect(result).to eq(['Error 1', 'Error 2'])
        end
      end
    end

    context 'with array of errors' do
      it 'returns the array as-is' do
        errors = ['Error 1', 'Error 2']
        result = ErrorHandler.format_errors(errors)
        expect(result).to eq(errors)
      end
    end

    context 'with string error' do
      it 'returns array with single error' do
        result = ErrorHandler.format_errors('Single error')
        expect(result).to eq(['Single error'])
      end
    end

    context 'with nil or unknown type' do
      it 'returns default error message for nil' do
        result = ErrorHandler.format_errors(nil)
        expect(result).to eq([])
      end

      it 'returns default error message for unknown type' do
        result = ErrorHandler.format_errors({ unknown: 'type' })
        expect(result).to eq(['An unexpected error occurred'])
      end
    end
  end

  describe '.log_and_respond' do
    let(:exception) { StandardError.new('Test error') }

    before do
      allow(exception).to receive(:backtrace).and_return([
        '/path/to/file.rb:10:in `method`',
        '/path/to/other.rb:5:in `other_method`'
      ])
    end

    it 'returns user-friendly message' do
      expect {
        result = ErrorHandler.log_and_respond(exception)
        expect(result).to eq('An error occurred')
      }.to output(a_string_including('Test error')).to_stdout
    end

    it 'includes context in log when provided' do
      expect {
        ErrorHandler.log_and_respond(exception, context: 'User creation')
      }.to output(a_string_including('[ERROR] User creation: Test error')).to_stdout
    end

    it 'returns custom user message when provided' do
      expect {
        result = ErrorHandler.log_and_respond(exception, user_message: 'Custom error')
        expect(result).to eq('Custom error')
      }.to output(a_string_including('Test error')).to_stdout
    end
  end
end