if (!ENV.key?('COV') && !ENV.key?('COVERAGE')) || (ENV['COV'] != 'false' && ENV['COVERAGE'] != 'false')
  require 'simplecov'
  SimpleCov.minimum_coverage 84
  SimpleCov.start 'rails'
end

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock/minitest'
require 'mocha/minitest'

# Load lib files for SimpleCov coverage without re-executing files already required at boot.
Dir[Rails.root.join('lib/**/*.rb')].each do |file|
  absolute = File.expand_path(file)
  require absolute unless $".include?(absolute)
end

# WebMock.allow_net_connect!
WebMock.disable_net_connect!

require 'html_validation'
#PageValidations::HTMLValidation.show_warnings = false

require "minitest/reporters"
Minitest::Reporters.use! [
  Minitest::Reporters::ProgressReporter.new
  #Minitest::Reporters::HtmlReporter.new # create html reporte with many more informations
]

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Make tests independants from others fixtures edition
  self.use_transactional_tests = false

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  # Associate delayed job class to customer
  set_fixture_class delayed_jobs: Delayed::Backend::ActiveRecord::Job
  # Associate route_data fixture files to RouteData model
  set_fixture_class route_data: RouteData
  set_fixture_class route_data_start: RouteData
  set_fixture_class route_data_stop: RouteData

  # Sync counter cache columns when tests bypass ActiveRecord callbacks (delete_all, SQL).
  def sync_customer_counters!(customer = nil)
    scope = customer ? Customer.where(id: customer.id) : Customer.all
    scope.find_each do |record|
      Customer.where(id: record.id).update_all(
        destinations_count: record.destinations.count,
        visits_count: Visit.joins(:destination).where(destinations: { customer_id: record.id }).count,
        plannings_count: record.plannings.count,
        vehicles_count: record.vehicles.count
      )
    end
  end

  def setup
    uri_template = Addressable::Template.new('gpp3-wxs.ign.fr/{api_key}/geoportail/ols')
    @stub_GeocodeRequest = stub_request(:post, uri_template).with { |request|
      request.body.include?("methodName='GeocodeRequest'")
    }.to_return(File.new(File.expand_path('../', __FILE__) + '/fixtures/gpp3-wxs.ign.fr/GeocodeRequest.xml').read)

    uri_template = Addressable::Template.new('gpp3-wxs.ign.fr/{api_key}/geoportail/ols')
    @stub_LocationUtilityService = stub_request(:post, uri_template).with { |request|
      request.body.include?("methodName='LocationUtilityService'")
    }.to_return(File.new(File.expand_path('../', __FILE__) + '/fixtures/gpp3-wxs.ign.fr/LocationUtilityService.xml').read)

    @stub_GeocodePlanner = stub_request(:get, %r{/0.1/geocode.json}).with(:query => hash_including({})).
      to_return(File.new(File.expand_path('../', __FILE__) + '/fixtures/geocoder/geocode.json').read)

    @stub_GeocodeComplete = stub_request(:patch, %r{/0.1/geocode.json}).with(:query => hash_including({})).
    to_return(File.new(File.expand_path('../', __FILE__) + '/fixtures/geocoder/geocode_complete.json').read)

    @stub_Analytics = stub_request(:post, %r{analytics}).to_return(status: 200)

    def (Planner::Application.config.geocoder).code_bulk(addresses)
      addresses.map{ |a| {lat: 1, lng: 1, quality: 'street', accuracy: 0.9} }
    end
  end

  def teardown
    remove_request_stub(@stub_GeocodeRequest)
    remove_request_stub(@stub_LocationUtilityService)
    remove_request_stub(@stub_GeocodePlanner)
    remove_request_stub(@stub_GeocodeComplete)
    remove_request_stub(@stub_Analytics)

    # FIXME: remove this code when errors due to locales are resolved
    if I18n.locale != :fr
      p "Wrong locale after test: #{self.class.name} > #{self.method_name}"
    end
  end

  def assert_valid(response)
    #    html_validation = PageValidations::HTMLValidation.new
    #    validation = html_validation.validation(response.body, response.to_s)
    #    assert validation.valid?, validation.exceptions
  end

  def without_loading(klass, options = {})
    begin
      # TODO: find another way to transmit options
      raise "without_loading cannot be used inside another without_loading block and different options" unless $_options.nil? || $_options == options
      $_options = options
      klass.class_eval do
        after_initialize :after_init
        def after_init
          raise "#{self.class.name} should not be loaded" if $_options[:if].nil? || $_options[:if].call(self)
        end
      end

      yield
    ensure
      klass.class_eval do
        def after_init
        end
      end
      $_options = nil
    end
  end
end

class ActionController::TestCase
  include Devise::Test::ControllerHelpers
end

def suppress_output
  begin
    original_stderr = $stderr.clone
    original_stdout = $stdout.clone
    $stderr.reopen(File.new('/dev/null', 'w'))
    $stdout.reopen(File.new('/dev/null', 'w'))
    retval = yield
  rescue Exception => e
    $stdout.reopen(original_stdout)
    $stderr.reopen(original_stderr)
    raise e
  ensure
    $stdout.reopen(original_stdout)
    $stderr.reopen(original_stderr)
  end
  retval
end

def clear_jobs
  jobs = JSON.parse(get_jobs(nil).body)
  jobs.each{ |job|
    delete_job(job['message']['id'])
  }
end

def delete_job(part, param = {})
  part = part ? '/' + part.to_s : ''
  delete "/api/0.1/jobs#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
end

def get_jobs(part, param = {})
  get "/api/0.1/jobs#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
end

if ENV['BENCHMARK'] == 'true'
  require 'capybara/rails'
  require 'capybara/minitest'
  require 'pi'
  require 'webdrivers/chromedriver'
  BENCHMARK_CPU_RATE = cpu_rate 17000

  # Browser testing configuration
  class ActionDispatch::IntegrationTest

    self.use_transactional_fixtures = false

    include Devise::Test::IntegrationHelpers

    # Make the Capybara DSL available in all integration tests
    include Capybara::DSL
    # Make `assert_*` methods behave like Minitest assertions
    include Capybara::Minitest::Assertions

    def setup
      WebMock.allow_net_connect!

      Capybara.run_server = true

      Capybara.app_host = 'http://localhost:3020'
      Capybara.server_host = 'localhost'
      Capybara.server_port = '3020'
      Capybara.configure do |config|
        config.default_host = 'http://localhost:3020'
      end

      # Full chrome version
      Capybara.register_driver :selenium_chrome do |app|
        browser_options = ::Selenium::WebDriver::Chrome::Options.new
        browser_options.args << '--window-size=1920x1080'
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
      end

      # Headless chrome version
      Capybara.register_driver :selenium_chrome_headless do |app|
        browser_options = ::Selenium::WebDriver::Chrome::Options.new
        browser_options.args << '--headless'
        browser_options.args << '--window-size=1920x1080'
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
      end

      Capybara.javascript_driver = :selenium_chrome

      Capybara.configure do |config|
        # Time after assert_selector fails (for instance to wait end of ajax query)
        config.default_max_wait_time = 45 # seconds
      end
    end

    # Reset sessions and driver between tests
    # Use super wherever this method is redefined in your individual test classes
    def teardown
      Capybara.reset_sessions!
      Capybara.use_default_driver
    end
  end
end
