require 'active_support/core_ext/integer/time'

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations
  config.action_view.raise_on_missing_translations = true

  config.raise_on_standard_error = false

  config.assets.compile = true

  # Application config

  config.action_mailer.default_url_options = {host: 'localhost'}

  config.default_from_mail = 'root@localhost'

  config.swagger_docs_base_path = 'http://localhost:3000/'
  config.api_contact_email = 'tech@cartoway.com'
  config.api_contact_url = 'https://github.com/cartoway/planner-web'

  def cache_factory(namespace, expires_in)
    ActiveSupport::Cache::NullStore.new
  end

  config.optimizer = OptimizerWrapper.new(
    cache_factory('optimizer_wrapper', 60*60*24*10),
    ENV['OPTIMIZER_URL'] || 'http://localhost:1791/0.1',
    ENV['OPTIMIZER_API_KEY']
  )
  config.optimize_time = nil
  config.optimize_time_force = 1
  config.optimize_minimal_time = nil
  config.optimize_max_split_size = 500
  config.optimize_cluster_size = 0
  config.optimize_stop_soft_upper_bound = 0.0
  config.optimize_vehicle_soft_upper_bound = 0.0
  config.optimize_overload_multiplier = 0
  config.optimize_cost_waiting_time = 1
  config.optimize_force_start = false

  config.geocode_code_cache = cache_factory('geocode', 60*60*24*10) # DEPRECATED, only for test
  config.geocode_reverse_cache = cache_factory('geocode_reverse', 60*60*24*10) # DEPRECATED, only for test
  config.geocode_complete_cache = cache_factory('geocode_complete', 60*60*24*10) # DEPRECATED, only for test
  config.geocode_complete = true # Build time setting

  require 'geocode_addok_wrapper'
  config.geocoder = GeocodeAddokWrapper.new(
    cache_factory('geocoder_wrapper', 60*60*24*10),
    ENV['GEOCODER_URL'] || 'http://localhost:8558/0.1',
    ENV['GEOCODER_API_KEY'] || 'demo'
  )

  config.router_osrm = Routers::Osrm.new(
    cache_factory('osrm_request', 60*60*24*1),
    cache_factory('osrm_result', 60*60*24*1)
  )
  config.router_otp = Routers::Otp.new(
    cache_factory('otp_request', 60*60*24*1),
    cache_factory('otp_result', 60*60*24*1)
  )
  config.router_here = Routers::Here.new(
    cache_factory('here_request', 60*60*24*1),
    cache_factory('here_result', 60*60*24*1),
    'https://route.api.here.com/routing',
    'https://matrix.route.api.here.com/routing',
    'https://isoline.route.api.here.com/routing',
    'app_id',
    'app_code'
  )
  config.router = Routers::RouterWrapper.new(
    cache_factory('router_wrapper_request', 60*60*24*1),
    cache_factory('router_wrapper_result', 60*60*24*1),
    ENV['ROUTER_API_KEY']
  )
  config.router.url = ENV['ROUTER_URL'] || 'http://localhost:4899/0.1'

  config.devices.alyacom.api_url = 'http://app.alyacom.fr/ws'
  config.devices.fleet.api_url = 'http://localhost:8084'
  config.devices.fleet.admin_api_key = ENV['DEVICE_FLEET_ADMIN_API_KEY']
  config.devices.masternaut.api_url = 'https://masternaut.example.com'
  config.devices.orange.api_url = 'https://orange.example.com'
  config.devices.praxedo.api_url = 'https://ww2.praxedo.com/eTech/services/'
  config.devices.sopac.api_url = "https://restservice1.bluconsole.com/bluconsolerest/1.0/resources/devices"
  config.devices.stg_telematics.api_url = 'https://stg-telematics.example.com'
  config.devices.tomtom.api_url = 'https://tomtom.example.com'
  config.devices.tomtom.api_key = ENV['DEVICE_TOMTOM_API_KEY']

  config.devices.cache_object = cache_factory('devices', 30)
  config.devices.deliver_cache_object = cache_factory('devices.deliver', 60*60*24*10)
  config.devices.stg_telematics_cache_object = cache_factory('devices.stg_telematics', 5 * 60)

  config.delayed_job_use = false

  config.self_care = true # If true, allow subscription and resiliation by the user himself

  config.manage_vehicles_only_admin = false # If true, only admin can add/remove vehicles

  config.enable_references = true
  config.enable_multi_visits = false

  config.display_javascript_errors_on_screen = false

  config.validate_during_duplication = true

  config.logger_sms = nil

  config.after_initialize do
    Bullet.enable               = false
    Bullet.alert                = false
    Bullet.bullet_logger        = false
    Bullet.console              = true
    Bullet.rails_logger         = true
    Bullet.add_footer           = false
    Bullet.counter_cache_enable = false
    Bullet.raise = true # raise an error if n+1 query occurs
  end

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  config.action_dispatch.cookies_same_site_protection = :strict
  config.session_store :cookie_store, key: '_cartoway_session', same_site: :strict
end

I18n.available_locales = [:fr]
I18n.enforce_available_locales = false
I18n.default_locale = :fr

module Nexmo
  class Client
    def initialize(options); end
    class SMS
      def send(options)
        puts 'local override Nexmo::Client...'
        puts options
        OpenStruct.new(messages: [OpenStruct.new(status: '0')])
      end
    end
    def sms
      SMS.new
    end
  end
end
