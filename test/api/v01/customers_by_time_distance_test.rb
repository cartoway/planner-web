require 'test_helper'

class V01::CustomerTestByTimeDistance < ActiveSupport::TestCase
  include Rack::Test::Methods
  set_fixture_class delayed_jobs: Delayed::Backend::ActiveRecord::Job

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
    @vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
  end

  def around
    Routers::Osrm.stub_any_instance(:matrix, lambda{ |url, vector| Array.new(vector.size, Array.new(vector.size, 0)) }) do
      yield
    end
  end

  def api(point, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/#{point}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=#{v}" }.join('&')
  end

  test 'should return customers by time and distance' do
    get api('destinations_by_time_and_distance', lat: 0, lng: 0, distance: 1, time: 1)
    assert last_response.ok?, last_response.body
  end

  test 'should return customers by distance' do
    get api('destinations_by_time_and_distance', lat: 0, lng: 0, distance: 1)
    assert last_response.ok?, last_response.body
  end

  test 'should return customers by time' do
    get api('destinations_by_time_and_distance', lat: 0, lng: 0, time: 1)
    assert last_response.ok?, last_response.body
  end

  test 'should return customers by time with vehicule_usage' do
    get api('destinations_by_time_and_distance', lat: 0, lng: 0, time: 1, vehicle_usage_id: @vehicle_usage.id)
    assert last_response.ok?, last_response.body
  end

  test 'should not return customers by time with invalid vehicule_usage' do
    get api('destinations_by_time_and_distance', lat: 0, lng: 0, time: 1, vehicle_usage_id: 666)
    assert !last_response.ok?, last_response.body
  end

  test 'should not return customers by nothing' do
    get api('destinations_by_time_and_distance', lat: 0, lng: 0)
    assert !last_response.ok?, last_response.body
  end

  test 'should return stores by distance' do
    get api('stores_by_distance', lat: 0, lng: 0, n: 5)
    assert last_response.ok?, last_response.body
  end

  test 'should return stores by distance with vehicule_usage' do
    get api('stores_by_distance', lat: 0, lng: 0, n: 5, vehicle_usage_id: @vehicle_usage.id)
    assert last_response.ok?, last_response.body
  end

  test 'should not return stores by distance with invalid vehicule_usage' do
    get api('stores_by_distance', lat: 0, lng: 0, n: 5, vehicle_usage_id: 666)
    assert !last_response.ok?, last_response.body
  end
end
