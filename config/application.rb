require File.expand_path('../boot', __FILE__)

require 'rails/all'
require_relative '../app/middleware/reseller_by_host'
require_relative '../lib/routers/osrm'
require_relative '../lib/routers/otp'
require_relative '../lib/routers/here'
require_relative '../lib/routers/router_wrapper'
require_relative '../lib/optim/optimizer_wrapper'
require_relative '../lib/exceptions'

require_relative '../lib/devices/device_base'
[
  'alyacom', 'fleet_demo', 'fleet', 'masternaut', 'notico', 'orange', 'deliver', 'praxedo',
  'sopac', 'stg_telematics', 'suivi_de_flotte', 'teksat', 'tomtom', 'trimble'
].each{|name|
  require_relative "../lib/devices/#{name}"
}

# Fixes OpenStruct + Ruby 1.9, for devices
unless OpenStruct.new.respond_to? :[]
  OpenStruct.class_eval do
    extend Forwardable
    def_delegators :@table, :[], :[]=
  end
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require 'devise'
require 'hashie'

module Mapotempo
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    I18n.available_locales = %w(en fr he pt es de id)

    config.autoload_paths += %W(#{config.root}/app/services #{config.root}/app/api/v01/helper #{config.root}/app/models/types)

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    config.active_record.schema_format = :sql

    # Application config

    config.assets.initialize_on_precompile = true

    config.middleware.use Rack::Config do |env|
      env['api.tilt.root'] = Rails.root.join 'app', 'api', 'views'
    end

    config.middleware.insert_before 0, 'Rack::Cors' do
      allow do
        origins '*'
        resource '/api-web/0.1/*', headers: :any, methods: [:get, :post, :options, :put, :delete, :patch]
        resource '/api/0.1/*', headers: :any, methods: [:get, :post, :options, :put, :delete, :patch]
        resource '/api/100/*', headers: :any, methods: [:get, :post, :options, :put, :delete, :patch]
      end
    end

    config.middleware.use ::ResellerByHost

    Hashie.logger = Rails.logger

    config.lograge.enabled = true
    config.lograge.custom_options = lambda do |event|
      unwanted_keys = %w[format action controller]
      customer_id = event.payload[:customer_id]
      sub_api = event.payload[:sub_api_time]
      params = event.payload[:params].reject { |key,_| unwanted_keys.include? key }

      {customer_id: customer_id, time: event.time, sub_api: sub_api, params: params}.delete_if{ |k, v| !v || v == 0 }
    end

    # Errors handling
    config.exceptions_app = self.routes

    # Option to display or not orders in Admin (not available in API)
    config.enable_orders = false

    # Option to display or not orders in Admin (not available in API)
    config.customer_test_default = true

    config.devices = OpenStruct.new(
      alyacom: Alyacom.new,
      fleet_demo: FleetDemo.new,
      fleet: Fleet.new,
      # locster: Locster.new,
      masternaut: Masternaut.new,
      notico: Notico.new,
      orange: Orange.new,
      deliver: Deliver.new,
      praxedo: Praxedo.new,
      stg_telematics: StgTelematics.new,
      sopac: Sopac.new,
      suivi_de_flotte: SuiviDeFlotte.new,
      teksat: Teksat.new,
      tomtom: Tomtom.new,
      trimble: Trimble.new
    )

    # Max number of models allowed by customer account
    config.max_plannings = 200
    config.max_plannings_default = nil
    config.max_zonings = 200
    config.max_zonings_default = nil
    config.max_destinations = 30000
    config.max_destinations_default = nil
    config.max_destinations_editable = 10000
    config.max_vehicle_usage_sets = 100
    config.max_vehicle_usage_sets_default = 1

    # Default values for icons
    config.tag_color_default = '#000000'.freeze
    config.tag_icon_default = 'fa-location-pin'.freeze
    config.tag_icon_size_default = 'medium'.freeze

    config.destination_color_default = '#707070'.freeze
    config.destination_icon_default = 'fa-location-pin'.freeze
    config.destination_icon_size_default = 'medium'.freeze

    config.route_color_default = config.destination_color_default

    config.store_color_default = '#000000'.freeze
    config.store_icon_default = 'fa-store'.freeze
    config.store_icon_size_default = 'large'.freeze
  end
end

ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  class_attr_index = html_tag.index 'class="'

  if class_attr_index
    html_tag.insert class_attr_index+7, 'ui-state-error '
  else
    html_tag.insert html_tag.index('>'), ' class="ui-state-error"'
  end
end
