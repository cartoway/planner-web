require 'test_helper'

class V01::RoutesGetTest < ActiveSupport::TestCase

  include Rack::Test::Methods

  # FIXME: utility to include ApiBase?
  # include ApiBase

  def app
    Rails.application
  end

  def api(path, params = {})
    Addressable::Template.new("/api/0.1/#{path}{?query*}").expand(query: params).to_s
  end

  setup do
    @route = routes :route_one_one
    @user = @route.planning.customer.users.take
  end

  test 'Export Route' do
    ['json', 'geojson', 'xml', 'ics'].each do |format|
      get api("/plannings/#{@route.planning_id}/routes/#{@route.id}.#{format}", api_key: @user.api_key)
      assert last_response.ok?, last_response.body
    end
  end

  test 'Export Route as iCalendar with E-Mail' do
    get api("/plannings/#{@route.planning_id}/routes/#{@route.id}.ics", api_key: @user.api_key, email: 1)
    assert_equal 204, last_response.status
  end

  test 'should return customer''s routes by ids in geojson' do
    get api("/plannings/#{@route.planning_id}/routes.geojson", api_key: @user.api_key, ids: [@route.id].join(''))
    assert last_response.ok?, last_response.body
    geojson = JSON.parse(last_response.body)
    assert geojson['features'].size > 0
    assert geojson['features'][0]['geometry']['coordinates']
    assert_nil geojson['features'][0]['geometry']['polylines']

    get api("/plannings/#{@route.planning_id}/routes.geojson", api_key: @user.api_key, ids: [@route.id].join(''), with_geojson: :polyline)
    assert last_response.ok?, last_response.body
    geojson = JSON.parse(last_response.body)
    assert geojson['features'].size > 0
    assert_nil geojson['features'][0]['geometry']['coordinates']
    assert geojson['features'][0]['geometry']['polylines']

    n_features = geojson['features'].size

    get api("/plannings/#{@route.planning_id}/routes.geojson", api_key: @user.api_key, ids: [@route.id].join(''), with_geojson: :polyline, stores: true)
    assert last_response.ok?, last_response.body
    geojson = JSON.parse(last_response.body)
    assert_equal n_features + 1, geojson['features'].size
  end

  test 'should return a route in geojson' do
    get api("/plannings/#{@route.planning_id}/routes/#{@route.id}.geojson", api_key: @user.api_key)
    assert last_response.ok?, last_response.body
    geojson = JSON.parse(last_response.body)
    assert geojson['features'].size > 0
    assert geojson['features'][0]['geometry']['coordinates']
    assert_nil geojson['features'][0]['geometry']['polylines']

    get api("/plannings/#{@route.planning_id}/routes/#{@route.id}.geojson", api_key: @user.api_key, with_geojson: :polyline)
    assert last_response.ok?, last_response.body
    geojson = JSON.parse(last_response.body)
    assert geojson['features'].size > 0
    assert_nil geojson['features'][0]['geometry']['coordinates']
    assert geojson['features'][0]['geometry']['polylines']
  end
end
