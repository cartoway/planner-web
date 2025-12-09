require 'test_helper'

class V01::RouteDataTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @route = routes(:route_one_one)
    @route_data = @route.start_route_data
  end

  def api(id, params = {})
    "/api/0.1/route_data/#{id}.json?api_key=testkey1&" + params.collect { |k, v| "#{k}=#{URI::DEFAULT_PARSER.escape(v.to_s)}" }.join('&')
  end

  test 'updates route_data hidden and color' do
    patch api(@route_data.id), hidden: true, color: '#123456'

    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal true, body['hidden']
    assert_equal '#123456', body['color']
    assert_equal true, @route_data.reload.hidden
    assert_equal '#123456', @route_data.color
  end
end
