require 'test_helper'

class PlanningsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
  end

  test 'should return json for planning during optim' do
    apply_job_optimizer_mode!(:during_optimization, @planning)
    get "/plannings/#{@planning.id}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)
    assert_not_nil json['optimizer']
  end

  test 'should return json for planning' do
    customers(:customer_one).update(job_optimizer_id: nil)
    get "/plannings/#{@planning.id}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)
    assert_equal @planning.routes.available.size, json['routes'].size
  end

  test 'should return devices with json for planning' do
    customers(:customer_one).update(job_optimizer_id: nil, devices: { deliver: { enable: true } }, enable_vehicle_position: true, enable_stop_status: true)

    get "/plannings/#{@planning.id}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)
    assert json['routes'].is_a?(Array)
    assert json['routes'].any? { |route| route.key?('devices') }
  end

  test 'should return json for stop by index' do
    customers(:customer_one).update(job_optimizer_id: nil)
    get "/routes/#{@planning.routes.first.id}/stops/by_index/1.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)
    assert json['stop_id']
    assert !json['manage_organize']
  end
end
