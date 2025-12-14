require 'jwt'
require 'securerandom'

class JwtService
  ALGORITHM = 'HS256'

  # Token expiry times (in seconds)
  ACCESS_TOKEN_EXPIRY = ENV['JWT_ACCESS_TOKEN_EXPIRY']&.to_i || 3600      # 1 hour
  REFRESH_TOKEN_EXPIRY = ENV['JWT_REFRESH_TOKEN_EXPIRY']&.to_i || 2592000 # 30 days

  class << self
    # Generate both access and refresh tokens for a user
    def generate_tokens(user, device_info = {})
      access_token = generate_access_token(user, device_info)
      refresh_token = generate_refresh_token(user, device_info)

      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: ACCESS_TOKEN_EXPIRY,
        token_type: 'Bearer'
      }
    end

    # Generate access token (short-lived)
    def generate_access_token(user, device_info = {})
      now = Time.current.to_i

      payload = {
        user_id: user.id,
        type: 'access',
        iat: now,
        exp: now + ACCESS_TOKEN_EXPIRY,
        jti: SecureRandom.uuid
      }

      # Add device info if provided
      payload[:device_type] = device_info[:device_type] if device_info[:device_type]
      payload[:device_id] = device_info[:device_id] if device_info[:device_id]

      JWT.encode(payload, jwt_secret, ALGORITHM)
    end

    # Generate refresh token (long-lived)
    def generate_refresh_token(user, device_info = {})
      now = Time.current.to_i

      payload = {
        user_id: user.id,
        type: 'refresh',
        iat: now,
        exp: now + REFRESH_TOKEN_EXPIRY,
        jti: SecureRandom.uuid
      }

      # Add device info if provided
      payload[:device_type] = device_info[:device_type] if device_info[:device_type]
      payload[:device_id] = device_info[:device_id] if device_info[:device_id]

      JWT.encode(payload, jwt_secret, ALGORITHM)
    end

    # Decode and validate any JWT token
    def decode_token(token)
      decoded = JWT.decode(token, jwt_secret, true, algorithm: ALGORITHM).first

      # Validate token structure
      return nil unless decoded['user_id'] && decoded['type'] && decoded['jti']

      # Return decoded payload with symbol keys for consistency
      decoded.transform_keys(&:to_sym)
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.warn("JWT decode error: #{e.message}") if defined?(Rails)
      nil
    end

    # Decode and validate access token specifically
    def decode_access_token(token)
      decoded = decode_token(token)
      return nil unless decoded && decoded[:type] == 'access'

      decoded
    end

    # Decode and validate refresh token specifically
    def decode_refresh_token(token)
      decoded = decode_token(token)
      return nil unless decoded && decoded[:type] == 'refresh'

      decoded
    end

    # Refresh access token using refresh token
    def refresh_access_token(refresh_token)
      decoded_refresh = decode_refresh_token(refresh_token)
      return nil unless decoded_refresh

      # Find the user
      user = User.find_by(id: decoded_refresh[:user_id])
      return nil unless user

      # Generate new access token with same device info
      device_info = {
        device_type: decoded_refresh[:device_type],
        device_id: decoded_refresh[:device_id]
      }.compact

      new_access_token = generate_access_token(user, device_info)

      {
        access_token: new_access_token,
        expires_in: ACCESS_TOKEN_EXPIRY,
        token_type: 'Bearer'
      }
    end

    # Extract user from access token
    def user_from_token(token)
      decoded = decode_access_token(token)
      return nil unless decoded

      User.find_by(id: decoded[:user_id])
    end

    # Validate token and return user (main method for authentication)
    def authenticate_token(token)
      user_from_token(token)
    end

    private

    def jwt_secret
      secret = ENV['JWT_SECRET']

      # In production, require a strong JWT secret
      if ENV['RACK_ENV'] == 'production' || ENV['RAILS_ENV'] == 'production'
        raise 'JWT_SECRET environment variable is required in production' if secret.blank?
        raise 'JWT_SECRET must be at least 32 characters long' if secret.length < 32
      end

      # Development/test fallback (same pattern as session secret)
      secret || 'development_jwt_secret_at_least_32_characters_long_for_security'
    end
  end
end