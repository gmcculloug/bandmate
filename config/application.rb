require 'dotenv/load'

class ApplicationConfig
  class << self
    def database_config
      if ENV['DATABASE_URL']
        ENV['DATABASE_URL']
      else
        {
          adapter: 'postgresql',
          host: database_host,
          port: database_port,
          database: database_name,
          username: database_username,
          password: database_password
        }
      end
    end

    def session_secret
      ENV['SESSION_SECRET'] || default_session_secret
    end

    def account_creation_secret
      ENV['BAND_HUDDLE_ACCT_CREATION_SECRET'] || default_account_creation_secret
    end

    def google_service_account_json
      ENV['GOOGLE_SERVICE_ACCOUNT_JSON']
    end

    def public_folder
      File.join(File.dirname(__FILE__), '..', 'public')
    end

    def views_folder
      File.join(File.dirname(__FILE__), '..', 'views')
    end

    def ssl_cert_path
      File.join(File.dirname(__FILE__), '..', 'ssl', 'server.crt')
    end

    def ssl_key_path
      File.join(File.dirname(__FILE__), '..', 'ssl', 'server.key')
    end

    def ssl_enabled?
      File.exist?(ssl_cert_path) && File.exist?(ssl_key_path)
    end

    def port
      ENV['PORT'] || 4567
    end

    def bind_address
      ENV['BIND_ADDRESS'] || '0.0.0.0'
    end

    def environment
      ENV['RACK_ENV'] || 'development'
    end

    private

    def database_host
      ENV['DATABASE_HOST'] || 'localhost'
    end

    def database_port
      ENV['DATABASE_PORT'] || 5432
    end

    def database_name
      case environment
      when 'development'
        ENV['DATABASE_NAME'] || 'band_huddle_development'
      when 'test'
        ENV['DATABASE_NAME'] || 'band_huddle_test'
      when 'production'
        ENV['DATABASE_NAME'] || 'band_huddle_production'
      end
    end

    def database_username
      ENV['DATABASE_USERNAME'] || 'postgres'
    end

    def database_password
      ENV['DATABASE_PASSWORD'] || ''
    end

    def default_session_secret
      if environment == 'development'
        'development_session_secret_that_is_very_long_and_secure_at_least_64_characters_long_for_local_development_only'
      else
        raise("SESSION_SECRET environment variable must be set for #{environment} environment")
      end
    end

    def default_account_creation_secret
      if environment == 'development'
        'dev_account_creation_code'
      else
        raise("BAND_HUDDLE_ACCT_CREATION_SECRET environment variable must be set for #{environment} environment")
      end
    end
  end
end

