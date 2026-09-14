require 'test_helper'

class V100::DestinationsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
    @customer.update(job_optimizer_id: nil)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/100/destinations#{part}.json?api_key=testkey1&" + param.collect { |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'GET destinations without page returns a bare array' do
    get api
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_kind_of Array, body
    assert_equal @customer.destinations.size, body.size
  end

  test 'GET destinations with page returns items envelope' do
    total = @customer.destinations.size
    get api(nil, page: 1, per_page: 2)
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal 1, body['page']
    assert_equal 2, body['per_page']
    assert_equal total, body['total']
    assert_equal 2, body['items'].size
    assert body['items'].first['id'].present?
  end
end
