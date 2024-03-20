Rails.application.configure do
   config.webpacker.check_yarn_integrity = false  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = false

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = false

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like
  # NGINX, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.serve_static_files = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  config.raise_on_standard_error = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Application config

  config.action_mailer.default_url_options = {host: 'localhost'}

  config.default_from_mail = 'root@localhost'

  config.swagger_docs_base_path = 'http://localhost:3000/'
  config.api_contact_email = 'tech@cartoway.com'
  config.api_contact_url = 'https://github.com/cartoway/planner-web'

  def cache_factory(namespace, expires_in)
    ActiveSupport::Cache::RedisStore.new(host: ENV['REDIS_HOST'] || 'localhost', namespace: namespace, expires_in: expires_in, raise_errors: true)
  end

#  config.optimize = Ort.new(
#    cache_factory('optimizer', 60*60*24*10),
#    'http://localhost:4567/0.1/optimize_tsptw'
#  )
  config.optimizer = OptimizerWrapper.new(
    cache_factory('optimizer_wrapper', 60*60*24*10),
    ENV['OPTIMIZER_URL'] || 'http://localhost:1791/0.1',
    ENV['OPTIMIZER_API_KEY']
  )
  config.optimize_time = 15
  config.optimize_time_force = nil
  config.optimize_minimal_time = 10
  config.optimize_max_split_size = 500
  config.optimize_cluster_size = 0
  config.optimize_stop_soft_upper_bound = 0.0
  config.optimize_vehicle_soft_upper_bound = 0.0
  config.optimize_overload_multiplier = 0
  config.optimize_cost_waiting_time = 1
  config.optimize_force_start = false

  config.geocode_complete = false # Build time setting

  require 'geocode_addok_wrapper'
  config.geocoder = GeocodeAddokWrapper.new(
    cache_factory('geocoder_wrapper', 60*60*24*10),
    ENV['GEOCODER_URL'] || 'http://localhost:8558/0.1',
    ENV['GEOCODER_API_KEY'] || 'demo'
  )

  # config.router_osrm = Routers::Osrm.new(
  #   cache_factory('osrm_request', 60*60*24*1),
  #   cache_factory('osrm_result', 60*60*24*1)
  # )
  # config.router_otp = Routers::Otp.new(
  #   cache_factory('otp_request', 60*60*24*1),
  #   cache_factory('otp_result', 60*60*24*1)
  # )
  # config.router_here = Routers::Here.new(
  #   cache_factory('here_request', 60*60*24*1),
  #   cache_factory('here_result', 60*60*24*1),
  #   'https://route.api.here.com/routing',
  #   'https://matrix.route.api.here.com/routing',
  #   'https://isoline.route.api.here.com/routing',
  #   nil,
  #   nil
  # )
  config.router = Routers::RouterWrapper.new(
    cache_factory('router_wrapper_request', 60*60*24*1),
    cache_factory('router_wrapper_result', 60*60*24*1),
    ENV['ROUTER_API_KEY']
  )
  config.router.url = ENV['ROUTER_URL'] || 'http://localhost:4899/0.1'

  config.devices.alyacom.api_url = 'http://app.alyacom.fr/ws'
  config.devices.fleet.api_url = 'https://fleet.cartoway.com'
  config.devices.fleet.admin_api_key = ENV['DEVICE_FLEET_ADMIN_API_KEY']
  config.devices.masternaut.api_url = 'http://gc.api.geonaut.masternaut.com/MasterWS/services'
  config.devices.orange.api_url = 'https://m2m-services.ft-dm.com'
  config.devices.praxedo.api_url = 'https://ww2.praxedo.com/eTech/services/'
  config.devices.sopac.api_url = "https://restservice1.bluconsole.com/bluconsolerest/1.0/resources/devices"
  config.devices.stg_telematics.api_url = 'https://api.stgfleet.com'
  config.devices.suivi_de_flotte.api_url = 'https://webservice.suivideflotte.net/service/'
  config.devices.tomtom.api_url = 'https://soap.business.tomtom.com/v1.30'
  config.devices.tomtom.api_key = ENV['DEVICE_TOMTOM_API_KEY']
  config.devices.trimble.api_url = 'https://soap.box.trimbletl.com/fleet-service/'

  config.devices.cache_object = cache_factory('devices', 30)
  config.devices.stg_telematics_cache_object = cache_factory('devices.stg_telematics', 5 * 60)

  config.delayed_job_use = true

  config.self_care = true # If true, allow subscription and resiliation by the user himself

  config.manage_vehicles_only_admin = false # If true, only admin can add/remove vehicles

  config.enable_references = true
  config.enable_multi_visits = false

  config.display_javascript_errors_on_screen = false

  config.validate_during_duplication = false

  config.logger_sms = nil
end
