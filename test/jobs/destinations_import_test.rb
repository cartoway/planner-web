# frozen_string_literal: true

require 'test_helper'
require 'destinations_import'

class DestinationsImportTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @customer.update!(job_destination_import: nil, job_destination_geocoding: nil, job_optimizer: nil)
    @original_delayed_job_use = Planner::Application.config.delayed_job_use
  end

  teardown do
    Planner::Application.config.delayed_job_use = @original_delayed_job_use
  end

  test 'enqueue creates blob and assigns job when delayed_job_use' do
    Planner::Application.config.delayed_job_use = true
    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_destinations_update.csv', 'text/csv')
    blob = DestinationsImport.persist_upload!(file)

    assert_difference('Delayed::Job.count', 1) do
      result = DestinationsImport.enqueue(@customer, source: 'csv', blob: blob, options: { replace: false })
      assert_kind_of Delayed::Backend::ActiveRecord::Job, result
    end
    @customer.reload
    assert @customer.job_destination_import
    assert_includes @customer.job_destination_import.handler, blob.id.to_s
  end

  test 'enqueue stores current locale in job options' do
    Planner::Application.config.delayed_job_use = true
    I18n.with_locale(:fr) do
      result = DestinationsImport.enqueue(@customer, source: 'tomtom', options: { replace: false })
      assert_kind_of Delayed::Backend::ActiveRecord::Job, result
      assert_match(/locale: ["']?fr["']?/, result.handler)
    end
  end

  test 'perform creates destinations synchronously when delayed_job_use is off' do
    Planner::Application.config.delayed_job_use = false
    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_destinations_without_visit.csv', 'text/csv')
    blob = DestinationsImport.persist_upload!(file)
    blob_id = blob.id
    before = Destination.count

    result = DestinationsImport.enqueue(@customer, source: 'csv', blob: blob, options: { replace: false })
    assert result
    assert_operator Destination.count, :>, before
    @customer.reload
    assert_nil @customer.job_destination_import
    assert_nil ActiveStorage::Blob.find_by(id: blob_id)
  end

  test 'refuses concurrent import' do
    Planner::Application.config.delayed_job_use = true
    job = Delayed::Job.enqueue(ImporterDestinationsJob.new(@customer.id, 'tomtom', nil, {}))
    @customer.update!(job_destination_import: job)

    result = DestinationsImport.enqueue(@customer, source: 'tomtom', options: { replace: false })
    assert_equal false, result
    assert @customer.errors[:base].any?
  end

  test 'cancel destroys job_destination_import fk' do
    Planner::Application.config.delayed_job_use = true
    job = Delayed::Job.enqueue(ImporterDestinationsJob.new(@customer.id, 'tomtom', nil, {}))
    @customer.update!(job_destination_import: job)
    job_id = job.id

    @customer.job_destination_import.destroy
    @customer.reload
    assert_nil @customer.job_destination_import
    assert_nil Delayed::Job.find_by(id: job_id)
  end

  test 'failed import jobs are destroyed but remembered in last_async_jobs' do
    assert_equal true, ImporterDestinationsJob.new(1, 'tomtom', nil, {}).destroy_failed_jobs?
  end

  test 'perform sets optimizer_context so import is not self-blocked by blocking_job' do
    Planner::Application.config.delayed_job_use = true
    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_destinations_without_visit.csv', 'text/csv')
    blob = DestinationsImport.persist_upload!(file)
    job = ImporterDestinationsJob.new(@customer.id, 'csv', blob.id, { replace: false, locale: 'en' })
    delayed = Delayed::Job.enqueue(job)
    @customer.update!(job_destination_import: delayed)
    assert @customer.blocking_job

    route = routes(:route_one_one)
    seen_context = nil
    ImportCsv.stub_any_instance(:import, lambda { |*_args|
      seen_context = Planning.optimizer_context
      route.update!(ref: 'ok-during-import')
      true
    }) do
      job.perform
    end

    assert_equal true, seen_context
    refute Planning.optimizer_context
    assert_equal 'ok-during-import', route.reload.ref
  end

  test 'import geocodes in-process and reports phase progress' do
    Planner::Application.config.delayed_job_use = true
    mock_geocoder = Object.new
    def mock_geocoder.code_bulk(_args)
      @called = true
      [{ lat: 48.8566, lng: 2.3522 }]
    end
    def mock_geocoder.called?
      @called
    end

    original_geocoder = Planner::Application.config.geocoder
    begin
      Planner::Application.config.geocoder = mock_geocoder
      progresses = []
      importer = ImporterDestinations.new(@customer)
      importer.progress_callback = ->(progress) { progresses << progress.dup }

      file = Rack::Test::UploadedFile.new('test/fixtures/files/import_destinations_without_visit.csv', 'text/csv')
      assert ImportCsv.new(importer: importer, replace: false, file: file).import(false)

      assert mock_geocoder.called?, 'Geocoder should run inside the import'
      @customer.reload
      assert_nil @customer.job_destination_geocoding
      phases = progresses.filter_map{ |p| p['phase'] || p[:phase] }
      assert_includes phases, 'destinations'
      assert_includes phases, 'geocoding'
      assert progresses.any?{ |p| p['destinations'] || p[:destinations] }
      assert progresses.any?{ |p| p['geocoding'] || p[:geocoding] }
    ensure
      Planner::Application.config.geocoder = original_geocoder
    end
  end
end
