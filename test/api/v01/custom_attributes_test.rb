require 'test_helper'

class V01::CustomAttributesTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  setup do
    @custom_attribute = custom_attributes(:custom_attribute_one)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/custom_attributes#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  def api_admin(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/custom_attributes#{part}.json?api_key=adminkey&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test "should return customer's custom_attributes" do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @custom_attribute.customer.custom_attributes.size, JSON.parse(last_response.body).size
  end

  test "should return customer's custom_attributes by ids" do
    get api(nil, 'ids' => @custom_attribute.id)
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
    assert_equal @custom_attribute.id, JSON.parse(last_response.body)[0]['id']
  end

  test 'should return a custom_attribute' do
    get api(@custom_attribute.id)
    assert last_response.ok?, last_response.body
    assert_equal @custom_attribute.name, JSON.parse(last_response.body)['name']
  end

  test 'should update a custom_attribute' do
    @custom_attribute.name = 'new name'
    put api(@custom_attribute.id), nil, input: @custom_attribute.attributes.merge({'object_type' => 'integer'}).to_json, CONTENT_TYPE: 'application/json'
    assert last_response.ok?, last_response.body

    get api(@custom_attribute.id)
    assert last_response.ok?, last_response.body
    custom_attributes = JSON.parse last_response.body
    assert_equal @custom_attribute.name, custom_attributes['name']
  end

  test 'should create a custom_attribute' do
    assert_difference('CustomAttribute.count', 1) do
      new_name = 'new custom'
      post api(), {name: new_name, default_value: 1.1, object_type: 'float', object_class: 'vehicle'}
      assert last_response.created?, last_response.body
      assert_equal new_name, JSON.parse(last_response.body)['name']
      assert_equal "1.1", JSON.parse(last_response.body)['default_value']
    end
  end
end
