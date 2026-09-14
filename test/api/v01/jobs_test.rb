require 'test_helper'

class V01::JobsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
    @customer.update!(
      job_optimizer_id: nil,
      job_destination_geocoding_id: nil,
      job_store_geocoding_id: nil
    )
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/jobs#{part}.json?api_key=testkey1&" + param.collect { |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'GET job returns succeeded from last_async_jobs' do
    finished_at = '2026-09-14T10:00:00Z'
    @customer.update!(last_async_jobs: {
      'optimizer' => { 'id' => 9_000_001, 'type' => 'optimizer', 'status' => 'succeeded', 'finished_at' => finished_at }
    })

    get api(9_000_001)
    assert_equal 200, last_response.status, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal 9_000_001, body['id']
    assert_equal 'succeeded', body['status']
    assert_equal 'optimizer', body['type']
    assert_equal finished_at, body['finished_at']
  end

  test 'GET job returns 404 for an id this customer never ran' do
    get api(9_000_404)
    assert_equal 404, last_response.status, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal 404, body['status']
    assert_equal 'Job not found.', body['message']
  end

  test 'GET job returns running for a live Delayed::Job' do
    job = delayed_jobs(:job_optimizer)
    @customer.update!(job_optimizer: job)

    get api(job.id)
    assert_equal 200, last_response.status, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal job.id, body['id']
    assert_equal 'running', body['status']
  end

  test 'GET jobs lists live jobs and last succeeded' do
    job = delayed_jobs(:job_optimizer)
    @customer.update!(
      job_optimizer: job,
      last_async_jobs: {
        'destination_geocoding' => { 'id' => 9_000_002, 'type' => 'geocoder', 'status' => 'succeeded', 'finished_at' => '2026-09-14T10:00:00Z' }
      }
    )

    get api
    assert_equal 200, last_response.status, last_response.body
    body = JSON.parse(last_response.body)
    assert_kind_of Array, body
    ids = body.map { |j| j['id'] }
    assert_includes ids, job.id
    assert_includes ids, 9_000_002
    assert_equal 'succeeded', body.find { |j| j['id'] == 9_000_002 }['status']
  end
end
