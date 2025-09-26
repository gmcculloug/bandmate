# Puma SSL configuration
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV") { "development" }

# SSL configuration - bind to HTTPS
ssl_bind '0.0.0.0', '4567', {
  key: File.join(File.dirname(__FILE__), '..', 'ssl', 'server.key'),
  cert: File.join(File.dirname(__FILE__), '..', 'ssl', 'server.crt'),
  verify_mode: 'none'
}