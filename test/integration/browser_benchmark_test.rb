require 'test_helper'

require 'benchmark'

if ENV['BENCHMARK'] == 'true'
  class BrowserBenchmarkTest < ActionDispatch::IntegrationTest
    setup do
      # Disable logs
      dev_null = Logger.new('/dev/null')
      Rails.logger = dev_null
      ActiveRecord::Base.logger = dev_null

      @customer = customers(:customer_one)
      @customer.max_vehicles = 80
      @customer.max_destinations = 30_000
      @customer.job_optimizer_id = nil
      @customer.job_destination_geocoding_id = nil
      @customer.save!

      @user = @customer.users.first

      Delayed::Job.destroy_all

      @importer = ImporterDestinations.new(@customer)

      def Job.on_planning(_job, _planning_id)
        false
      end

      Capybara.current_driver = :selenium_chrome_headless

      sign_in(@user, scope: :user)
    end

    def around
      Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |_url, _mode, _dimension, segments, _options| segments.collect { |_| [1000, 60, '_ibE_seK_seK_seK'] } }) do
        yield
      end
    end

    # Under 1000 points markers are clusterized and routes collapsed
    focus
    test 'should show a planning with 900 points in less than 40 seconds' do
      file = fixture_file_upload('test/fixtures/files/import_destinations_benchmark_900.csv')
      import_csv = ImportCsv.new(importer: @importer, replace: false, file: file)
      import_csv.import

      # Use the first planning which has no tags
      @planning = @customer.plannings.first
      @planning.compute
      @planning.save!

      time_ref = 40.seconds
      time_elapsed = Benchmark.realtime do
        visit edit_planning_path(@planning)

        assert_selector '.routes.ui-sortable'
        assert_no_selector 'body.ajax_waiting'
      end.round

      p "Time for displaying 900 points in browser: #{time_elapsed} seconds (should be less than #{time_ref})"

      assert_operator time_elapsed, :<=, time_ref
    end

    # Markers are clusterized and routes collapsed
    focus
    test 'should show a planning with 4 000 points in less than 30 seconds' do
      file = fixture_file_upload('test/fixtures/files/import_destinations_benchmark_4000.csv')
      import_csv = ImportCsv.new(importer: @importer, replace: false, file: file)
      import_csv.import

      # Use the first planning which has no tags
      @planning = @customer.plannings.first
      @planning.compute
      @planning.save!

      time_ref = 30.seconds
      time_elapsed = Benchmark.realtime do
        visit edit_planning_path(@planning)

        assert_selector '.routes.ui-sortable'
        assert_no_selector 'body.ajax_waiting'
      end.round

      p "Time for displaying 4000 points in browser: #{time_elapsed} seconds (should be less than #{time_ref})"

      assert_operator time_elapsed, :<=, time_ref
    end
  end
end
