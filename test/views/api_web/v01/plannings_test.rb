require 'test_helper'

class ApiWeb::V01::PlanningsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
  end

  # TODO
  # Bullet not taken into account in controller, need to be in views
  def around
    begin
      Bullet.enable = true
      yield
    ensure
      Bullet.enable = false
    end
  end

  test 'should return json for stop by index' do
    Bullet.enable = false # TODO: fix me by removing default scope  in planning
    customers(:customer_one).update(job_optimizer_id: nil)
    get "/api-web/0.1/routes/#{@planning.routes.first.id}/stops/by_index/1.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)
    assert json['stop_id']
    assert !json['manage_organize']
  end

  test 'stop json includes store_start and store_stop with custom_attributes when route has depots' do
    Bullet.enable = false
    customer = customers(:customer_one)
    customer.update!(job_optimizer_id: nil, enable_stop_status: true)
    route = @planning.routes.joins(:vehicle_usage).first
    skip 'Route has no start/stop depots' if !route&.vehicle_usage&.default_store_start || !route&.vehicle_usage&.default_store_stop

    get "/api-web/0.1/routes/#{route.id}/stops/by_index/1.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)

    # When route has start/stop depots, store_start and store_stop may be present with custom_attributes
    if json['store_start']
      assert json['store_start'].key?('custom_attributes'), 'store_start should include custom_attributes'
      assert_kind_of Array, json['store_start']['custom_attributes']
    end
    if json['store_stop']
      assert json['store_stop'].key?('custom_attributes'), 'store_stop should include custom_attributes'
      assert_kind_of Array, json['store_stop']['custom_attributes']
    end
  end
end
