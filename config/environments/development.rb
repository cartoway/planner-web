require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  config.action_view.raise_on_missing_translations = true

  config.raise_on_standard_error = false

  # Application config
  # Display sent email at http://localhost:8080/letter_opener
  # Use :letter_opener to automatically open email in browser
  config.action_mailer.delivery_method = :letter_opener

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { :host => 'localhost:8080' } # Needed by devise
  config.action_mailer.smtp_settings = {
    address: 'smtp.example.com',
    port: 587,
    user_name: 'robot@example.com',
    password: '',
    authentication: 'plain',
    enable_starttls: true,
    open_timeout: 5,
    read_timeout: 5,
  }
  config.default_from_mail = 'root@localhost'

  config.swagger_docs_base_path = 'http://localhost:8080/'
  config.api_contact_email = 'tech@cartoway.com'
  config.api_contact_url = 'https://github.com/cartoway/planner-web'

  def cache_factory(namespace, expires_in)
    ActiveSupport::Cache::FileStore.new(File.join(Dir.tmpdir, namespace), namespace: namespace, expires_in: expires_in)
  end

  config.planner_cache = cache_factory('planner', 60*60*12*1)

  config.optimizer = OptimizerWrapper.new(
    cache_factory('optimizer_wrapper', 60*60*24*10),
    ENV['OPTIMIZER_URL'] || 'http://localhost:1791/0.1',
    ENV['OPTIMIZER_API_KEY'] || 'demo'
  )

  config.optimize_time = 60
  config.optimize_time_force = nil
  config.optimize_minimal_time = 15
  config.optimize_max_split_size = 500
  config.optimize_cluster_size = 0
  config.optimize_stop_soft_upper_bound = 0.0
  config.optimize_vehicle_soft_upper_bound = 0.0
  config.optimize_overload_multiplier = 0
  config.optimize_cost_fixed = 3.hours.to_i
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
    ENV['ROUTER_API_KEY'] || 'demo'
  )
  config.router.url = ENV['ROUTER_URL'] || 'http://localhost:4899/0.1'

  config.devices.alyacom.api_url = 'http://partners.alyacom.fr/ws'
  config.devices.fleet.api_url = 'http://0.0.0.0:8084'
  config.devices.fleet.admin_api_key = ENV['DEVICE_FLEET_ADMIN_API_KEY'] || 'demo'
  config.devices.masternaut.api_url = 'http://ws.webservices.masternaut.fr/MasterWS/services'
  config.devices.orange.api_url = 'https://m2m-services.ft-dm.com'
  config.devices.praxedo.api_url = 'https://ww2.praxedo.com/eTech/services/'
  config.devices.sopac.api_url = 'https://restservice1.bluconsole.com/bluconsolerest/1.0/resources/devices'
  config.devices.stg_telematics.api_url = 'https://api.stgfleet.com'
  config.devices.suivi_de_flotte.api_url = 'https://webservice.suivideflotte.net/service/'
  config.devices.tomtom.api_url = 'https://soap.business.tomtom.com/v1.30'
  config.devices.tomtom.api_key = ENV['DEVICE_TOMTOM_API_KEY']
  config.devices.trimble.api_url = 'https://soap.box.trimbletl.com/fleet-service/'

  config.devices.cache_object = cache_factory('devices', 30)
  config.devices.deliver_cache_object = cache_factory('devices.deliver', 60*60*24*10)
  config.devices.stg_telematics_cache_object = cache_factory('devices.stg_telematics', 5 * 60)

  config.delayed_job_use = true

  config.self_care = true # If true, allow subscription and resiliation by the user himself

  config.manage_vehicles_only_admin = false # If true, only admin can add/remove vehicles

  config.enable_references = true # Default value when create new customer account of display or not references

  config.display_javascript_errors_on_screen = true

  # N 1 Queries: display only in log or console
  config.after_initialize do
    Bullet.enable               = true
    Bullet.alert                = false
    Bullet.bullet_logger        = false
    Bullet.console              = false
    Bullet.rails_logger         = true
    Bullet.add_footer           = false
    Bullet.counter_cache_enable = true
  end

  config.validate_during_duplication = true

  config.logger_sms = nil

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  config.action_dispatch.cookies_same_site_protection = :strict
  config.session_store :cookie_store, key: '_cartoway_session', same_site: :strict
end
