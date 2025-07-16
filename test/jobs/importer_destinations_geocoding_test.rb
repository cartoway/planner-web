require 'test_helper'

class ImporterDestinationsGeocodingTest < ActiveSupport::TestCase
  setup do
    @original_locale = I18n.locale
    I18n.locale = :en
    @customer = customers(:customer_one)
    @customer.update(job_destination_geocoding: nil)
    @importer = ImporterDestinations.new(@customer)
    @store_to_geocode = @customer.stores.not_positioned.count
    @destinations_to_geocode = @customer.destinations.not_positioned.count
  end

  teardown do
    I18n.locale = @original_locale
  end

  test 'geocoding tasks are called in synchronous mode' do
    mock_geocoder = Object.new
    def mock_geocoder.code_bulk(args)
      @called = true
      [
        { lat: 48.8566, lng: 2.3522 },
        { lat: 45.7578, lng: 4.8320 }
      ]
    end
    def mock_geocoder.called?
      @called
    end

    original_geocoder = Planner::Application.config.geocoder
    original_delayed_job_use = Planner::Application.config.delayed_job_use

    begin
      Planner::Application.config.geocoder = mock_geocoder
      Planner::Application.config.delayed_job_use = false

      destinations_data = [
        {
          name: "Test Destination 1",
          city: "Paris",
          postalcode: "75001"
        },
        {
          name: "Test Destination 2",
          city: "Lyon",
          postalcode: "69001"
        }
      ]

      @importer.import(destinations_data, 'test_import', true, {}) { |row, line| row }

      assert mock_geocoder.called?, "Geocoder should have been called"
    ensure
      Planner::Application.config.geocoder = original_geocoder
      Planner::Application.config.delayed_job_use = original_delayed_job_use
    end
  end

  test 'geocoding job is enqueued in asynchronous mode' do
    original_delayed_job_use = Planner::Application.config.delayed_job_use

    begin
      Planner::Application.config.delayed_job_use = true

      destinations_data = [
        {
          name: "Test Destination 1",
          city: "Paris",
          postalcode: "75001"
        }
      ]

      @importer.import(destinations_data, 'test_import', false, {}) { |row, line| row }

      assert_not_nil @customer.job_destination_geocoding, "Customer should have a geocoding job assigned"
    ensure
      Planner::Application.config.delayed_job_use = original_delayed_job_use
    end
  end

  test 'geocoding tasks are called for both destinations and stores' do
    mock_geocoder = Object.new
    def mock_geocoder.code_bulk(args)
      @call_count ||= 0
      @call_count += 1
      [{ lat: 48.8566, lng: 2.3522 }]
    end
    def mock_geocoder.call_count
      @call_count || 0
    end

    original_geocoder = Planner::Application.config.geocoder
    original_delayed_job_use = Planner::Application.config.delayed_job_use

    begin
      Planner::Application.config.geocoder = mock_geocoder
      Planner::Application.config.delayed_job_use = false

      import_data = [
        {
          name: "Test Destination",
          city: "Paris",
          postalcode: "75001",
          stop_type: "visit"
        },
        {
          name: "Test Store",
          city: "Lyon",
          postalcode: "69001",
          stop_type: "store"
        }
      ]

      @importer.import(import_data, 'test_import', true, {}) { |row, line| row }

      assert_equal 2, mock_geocoder.call_count, "Geocoder should have been called twice"
    ensure
      Planner::Application.config.geocoder = original_geocoder
      Planner::Application.config.delayed_job_use = original_delayed_job_use
    end
  end

  test 'geocoding job is not enqueued when no destinations need geocoding' do
    original_delayed_job_use = Planner::Application.config.delayed_job_use

    begin
      @customer.stores.not_positioned.each{ |store| store.update(lat: 1, lng: 2) }
      assert_nil @customer.job_destination_geocoding, "Test should be initiated without an existing job"
      Planner::Application.config.delayed_job_use = true

      destinations_data = [
        {
          name: "Test Destination 1",
          city: "Paris",
          postalcode: "75001",
          lat: 48.8566,
          lng: 2.3522
        }
      ]

      @importer.import(destinations_data, 'test_import', false, {}) { |row, line| row }

      assert_nil @customer.job_destination_geocoding, "Customer should not have a geocoding job when destinations already have coordinates"
    ensure
      Planner::Application.config.delayed_job_use = original_delayed_job_use
    end
  end

  test 'geocoding handles geocoding errors gracefully' do
    mock_geocoder = Object.new
    def mock_geocoder.code_bulk(args)
      @called = true
      raise GeocodeError.new("Geocoding failed")
    end
    def mock_geocoder.called?
      @called
    end

    original_geocoder = Planner::Application.config.geocoder
    original_delayed_job_use = Planner::Application.config.delayed_job_use

    begin
      Planner::Application.config.geocoder = mock_geocoder
      Planner::Application.config.delayed_job_use = false

      destinations_data = [
        {
          name: "Test Destination",
          city: "Invalid City",
          postalcode: "00000"
        }
      ]

      assert_nothing_raised do
        @importer.import(destinations_data, 'test_import', true, {}) { |row, line| row}
      end

      assert mock_geocoder.called?, "Geocoder should have been called despite the error"
    ensure
      Planner::Application.config.geocoder = original_geocoder
      Planner::Application.config.delayed_job_use = original_delayed_job_use
    end
  end

  test 'geocoding counts are tracked correctly' do
    original_delayed_job_use = Planner::Application.config.delayed_job_use

    begin
      Planner::Application.config.delayed_job_use = false

      destinations_data = [
        {
          name: "Test Destination 1",
          city: "Paris",
          postalcode: "75001"
        },
        {
          name: "Test Destination 2",
          city: "Lyon",
          postalcode: "69001"
        }
      ]

      @importer.import(destinations_data, 'test_import', true, {}) { |row, line| row }

      assert_equal @destinations_to_geocode + 2, @importer.instance_variable_get(:@destinations_to_geocode_count)
      assert_equal @store_to_geocode + 0, @importer.instance_variable_get(:@stores_to_geocode_count)
    ensure
      Planner::Application.config.delayed_job_use = original_delayed_job_use
    end
  end

  test 'geocoding job is enqueued with correct parameters when destinations need geocoding' do
    original_delayed_job_use = Planner::Application.config.delayed_job_use

    begin
      Planner::Application.config.delayed_job_use = true

      destinations_data = [
        {
          name: "Test Destination",
          city: "Paris",
          postalcode: "75001"
        }
      ]

      @importer.import(destinations_data, 'test_import', false, {}) { |row, line| row }

      assert_not_nil @customer.job_destination_geocoding, "Customer should have a geocoding job assigned"
    ensure
      Planner::Application.config.delayed_job_use = original_delayed_job_use
    end
  end
end
