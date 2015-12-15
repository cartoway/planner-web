require 'test_helper'

class V01::CustomerTestByTimeDistance < ActiveSupport::TestCase
  include Rack::Test::Methods
  set_fixture_class delayed_jobs: Delayed::Backend::ActiveRecord::Job

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
  end

  def around
    Osrm.stub_any_instance(:matrix, lambda{ |url, vector| Array.new(vector.size, Array.new(vector.size, 0)) }) do
      yield
    end
  end

  def api(param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/destinations_by_time_and_distance.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=#{v}" }.join('&')
  end

  test 'should return customers by time and distance' do
    get api(lat: 0, lng: 0, distance: 1, time: 1)
    assert last_response.ok?, last_response.body
  end

  test 'should return customers by distance' do
    get api(lat: 0, lng: 0, distance: 1)
    assert last_response.ok?, last_response.body
  end

  test 'should return customers by time' do
    get api(lat: 0, lng: 0, time: 1)
    assert last_response.ok?, last_response.body
  end

  test 'should not return customers by nothing' do
    get api(lat: 0, lng: 0)
    assert !last_response.ok?, last_response.body
  end
end
