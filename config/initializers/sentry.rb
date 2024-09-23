# frozen_string_literal: true

if ENV['SENTRY_DSN']
  Sentry.init { |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  }
elsif ENV['APP_ENV'] == 'production'
  puts 'WARNING: Sentry DSN should be defined for production'
end
