require 'test_helper'

class V100::RelationsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @relation = stops_relations(:relation_one)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/100/relations#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI.escape(v.to_s) }.join('&')
  end

  test "should return customer's relations" do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @relation.customer.stops_relations.size, JSON.parse(last_response.body).size
  end

  test "should return customer's relations by ids" do
    get api(nil, 'ids' => "#{@relation.id}")
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal 1, body.size
    assert_includes(body.map { |p| p['id'] }, @relation.id)
  end

  test 'should return a relation' do
    get api(@relation.id)
    assert last_response.ok?, last_response.body
    assert_equal @relation.relation_type, JSON.parse(last_response.body)['relation_type']
  end

  test 'should not create a pickup_delivery with same current_id' do
    post api(), @relation.attributes
    assert_equal 400, last_response.status, 'Bad response: ' + last_response.body
  end

  test 'should create an ordered relation' do
    assert_difference('StopsRelation.count', 1) do
      post api(), { relation_type: 'ordered', current_id: visits(:visit_three).id, successor_id: visits(:visit_two).id }
      assert last_response.created?, last_response.body

      # Visits three and two are already in use. This is not possible for pickup_delivery relation
      post api(), { relation_type: 'pickup_delivery', current_id: visits(:visit_three).id, successor_id: visits(:visit_two).id }
      assert_equal 400, last_response.status, last_response.body
    end
  end

  test 'should update a relation' do
    @relation.relation_type = 'same_vehicle'
    put api(@relation.id), relation_type: 'sequence'
    assert last_response.ok?, last_response.body

    get api(@relation.id)
    assert last_response.ok?, last_response.body
    assert_equal 'sequence', JSON.parse(last_response.body)['relation_type']
  end

  test 'should destroy a relation' do
    assert_difference('StopsRelation.count', -1) do
      delete api(@relation.id)
      assert_equal 204, last_response.status, last_response.body
    end
  end
end
