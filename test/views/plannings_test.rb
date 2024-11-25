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
    user = 'driver1'
    fleet_user = Digest::SHA256.hexdigest("#{user}@example.com")
    customers(:customer_one).update(job_optimizer_id: nil, devices: { fleet: { enable: true, user: user, api_key: '123456' } }, enable_vehicle_position: true, enable_stop_status: true)
    vehicles(:vehicle_one).update(devices: { fleet_user: fleet_user })

    stub_request(:get, %r{/api/0.1/users\?with_vehicle=true}).
    to_return(status: 200, body: "{
      \"users\": [
        {
          \"id\": \"user-fIxc7jcZYs\",
          \"company_id\": \"company-fIxbpq7vNj\",
          \"api_key\": \"xwfROQlB1hjao1Z4TKeokAtt\",
          \"sync_user\": \"#{fleet_user}\",
          \"name\": \"#{user}\",
          \"email\": \"#{user}@example.com\",
          \"vehicle\": true,
          \"color\": \"#fd108e\"
        }
      ]}", headers: {})

    get "/plannings/#{@planning.id}.json?api_key=testkey1"
    json = JSON.parse(last_response.body)
    assert_equal fleet_user, json['routes'][2]['devices']['fleet_user']['id']
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
