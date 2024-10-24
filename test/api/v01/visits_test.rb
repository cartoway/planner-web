require 'test_helper'

class V01::VisitsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActionDispatch::TestProcess

  def app
    Rails.application
  end

  setup do
    @destination = destinations(:destination_one)
    @visit = visits(:visit_one)
    clear_jobs
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/visits#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=#{v}" }.join('&')
  end

  def api_destination(destination_id, part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/destinations/#{destination_id}/visits#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=#{v}" }.join('&')
  end

  test "should return destination's visits" do
    get api_destination(@destination.id)
    assert last_response.ok?, last_response.body
    assert_equal @destination.visits.size, JSON.parse(last_response.body).size
  end

  test "should return destination's visits by ids" do
    get api_destination(@destination.id, nil, 'ids' => @visit.id)
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
    assert_equal @visit.id, JSON.parse(last_response.body)[0]['id']
  end

  test 'should return a visit' do
    get api_destination(@destination.id, @visit.id)
    assert last_response.ok?, last_response.body
    assert_equal @visit.ref, JSON.parse(last_response.body)['ref']
  end

  test 'should return a visit by ref' do
    get api_destination(@destination.id, "ref:#{@visit.ref}")
    assert last_response.ok?, last_response.body
    assert_equal @visit.ref, JSON.parse(last_response.body)['ref']
  end

  test 'should create a visit' do
    # tags can be a string separated by comma or an array
    [
      tags(:tag_one).id.to_s + ',' + tags(:tag_two).id.to_s,
      [tags(:tag_one).id, tags(:tag_two).id]
    ].each.with_index do |tags, index|
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count', 2) do
          post api_destination(@destination.id), @visit.attributes.merge({ref: "foo#{index}", tag_ids: tags, 'quantities' => [{deliverable_unit_id: 1, quantity: 3.5}]}).except('id').to_json, 'CONTENT_TYPE' => 'application/json'

          assert last_response.created?, last_response.body
          visit = JSON.parse last_response.body
          assert_equal 2, visit['tag_ids'].size
          assert_equal 3.5, visit['quantities'][0]['quantity']
          assert_equal '10:00:00', visit['time_window_start_1']
          assert_equal '11:00:00', visit['time_window_end_1']
          assert_equal 4, visit['priority']
          assert_equal '00:05:33', visit['duration']
          assert_equal '00:05:00', visit['duration_default']
        end
      end
    end
  end

  test 'should create a visit with negative quantity' do
    # tags can be a string separated by comma or an array
    [
      tags(:tag_one).id.to_s + ',' + tags(:tag_two).id.to_s,
      [tags(:tag_one).id, tags(:tag_two).id]
    ].each.with_index do |tags, index|
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count', 2) do
          post api_destination(@destination.id), @visit.attributes.merge({ref: "foo#{index}", tag_ids: tags, 'quantities' => [{deliverable_unit_id: 1, quantity: -3.5}]}).except('id').to_json, 'CONTENT_TYPE' => 'application/json'

          assert last_response.created?, last_response.body
          visit = JSON.parse last_response.body
          assert_equal 2, visit['tag_ids'].size
          assert_equal -3.5, visit['quantities'][0]['quantity']
          assert_equal '10:00:00', visit['time_window_start_1']
          assert_equal '11:00:00', visit['time_window_end_1']
          assert_equal '00:05:33', visit['duration']
          assert_equal '00:05:00', visit['duration_default']
        end
      end
    end
  end

  test 'should create a visit with none tag' do
    ['', nil, []].each.with_index do |tags, index|
      assert_difference('Visit.count', 1) do
        post api_destination(@destination.id), @visit.attributes.merge({ref: "foo#{index}", tag_ids: tags, 'quantities' => nil}).except('id'), as: :json
        assert last_response.created?, last_response.body
      end
    end
  end

  test 'should not create a visit' do
    post api_destination(@destination.id), @visit.attributes.merge(tag_ids: [tags(:tag_three).id], 'quantities' => nil).except('id'), as: :json
    assert_equal 400, last_response.status, last_response.body
  end

  test 'should update a visit' do
    [
      tags(:tag_one).id.to_s + ',' + tags(:tag_two).id.to_s,
      [tags(:tag_one).id, tags(:tag_two).id],
      '',
      nil,
      []
    ].each do |tags|
      put api_destination(@destination.id, @visit.id), @visit.attributes.merge({tag_ids: tags, 'quantities' => [{deliverable_unit_id: 1, quantity: 3.5}, {deliverable_unit_id: 2, quantity: 3.5}]}).except('force_position').to_json, 'CONTENT_TYPE' => 'application/json'
      assert last_response.ok?, last_response.body

      get api_destination(@destination.id, @visit.id)
      assert last_response.ok?, last_response.body
      visit = JSON.parse last_response.body
      assert_equal @visit.ref, visit['ref']
      assert_equal [3.5, 3.5], visit['quantities'].map{ |q| q['quantity'] }
    end
  end

  test 'should update a visit with quantities or return parse error' do

    put api_destination(@destination.id, @visit.id), { quantities: [{ deliverable_unit_id: 1, quantity: 10 }] }.to_json, 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?, last_response.body

    visit = JSON.parse(last_response.body)
    assert visit['quantities'][0]['deliverable_unit_id'], 1
    assert visit['quantities'][0]['quantity'], 10

    put api_destination(@destination.id, @visit.id), { quantities: [{ deliverable_unit_id: 1, quantity: -10 }] }.to_json, 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?, last_response.body

    visit = JSON.parse(last_response.body)
    assert visit['quantities'][0]['deliverable_unit_id'], 1
    assert visit['quantities'][0]['quantity'], -10

    put api_destination(@destination.id, @visit.id), { quantities: [{ deliverable_unit: 1, quantity: 'aaa' }] }.to_json, 'CONTENT_TYPE' => 'application/json'
    assert last_response.bad_request?
    response = JSON.parse(last_response.body)
    assert_equal response['message'], 'quantities[0][quantity] is invalid, quantities[0][deliverable_unit_id], quantities[0][quantity] provide all or none of parameters'
  end

  test 'should destroy a visit' do
    assert_difference('Visit.count', -1) do
      delete api_destination(@destination.id, @visit.id)
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test "should return customer's visits" do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @destination.customer.visits.size, JSON.parse(last_response.body).size
  end

  test 'should return customer''s visits geojson' do
    get api.gsub('.json', '.geojson') + '&quantities=true'
    assert last_response.ok?, last_response.body
    features = JSON.parse(last_response.body)['features']
    assert_equal @destination.customer.visits.size, features.size
    features.each{ |feat|
      assert feat['properties']['quantities'].size > 0
    }
  end

  test 'should return specific visits' do
    get api(nil, ids: "ref:#{visits(:visit_one).ref},#{visits(:visit_two).id}")
    assert last_response.ok?, last_response.body
    assert_equal 2, JSON.parse(last_response.body).size
  end

  test 'should destroy multiple visits' do
    assert_difference('Visit.count', -2) do
      delete api + "&ids=#{visits(:visit_one).id},#{visits(:visit_two).id}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy all visits without params' do
    assert_difference('Visit.count', -customers(:customer_one).visits.count) do
      delete api
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy all visits when all ids/ref in params' do
    ref = visits(:visit_two).ref
    assert_difference('Visit.count', -Visit.where(ref: ref).count) do
      delete api + "&ids=#{visits(:visit_one).id},ref:#{ref}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should create a visit using deprecated time fields' do
    assert_difference('Visit.count', 1) do
      visit_attributes = @visit.attributes
      visit_attributes['open1'] = @visit.time_window_start_1_time_with_seconds
      visit_attributes.delete 'time_window_start_1'
      visit_attributes['close1'] = @visit.time_window_end_1_time_with_seconds
      visit_attributes.delete 'time_window_end_1'
      post api_destination(@destination.id), visit_attributes.merge(ref: 'foo').except('id', 'quantities'), as: :json
      assert last_response.created?, last_response.body

      visit = JSON.parse(last_response.body)
      assert_equal '10:00:00', visit['time_window_start_1']
      assert_equal '11:00:00', visit['time_window_end_1']
    end
  end

  test 'should not create a visit using both current and deprecated time fields' do
    assert_difference('Visit.count', 0) do
      visit_attributes = @visit.attributes
      visit_attributes['open1'] = @visit.time_window_start_1_time_with_seconds
      visit_attributes['close1'] = @visit.time_window_end_1_time_with_seconds
      post api_destination(@destination.id), visit_attributes.except('id', 'quantities'), as: :json
      refute last_response.created?, last_response.body
      assert_equal 400, last_response.status, last_response.body
      assert_match "time_window_start_1, open1 are mutually exclusive", JSON.parse(last_response.body)['message']
      assert_match "time_window_end_1, close1 are mutually exclusive", JSON.parse(last_response.body)['message']
    end
  end

  test 'should not create a visit using an existing ref' do
    assert_difference('Visit.count', 0) do
      @visit.update(ref: 'foo')
      visit_attributes = @visit.attributes
      post api_destination(@destination.id), visit_attributes.except('id', 'quantities'), as: :json
      refute last_response.created?, last_response.body
      assert_equal 400, last_response.status, last_response.body
      assert_match "Référence est déjà utilisé(e)", JSON.parse(last_response.body)['message']
    end
  end

  test 'should create visit with correct position' do
    positions = %w[always_first always_final never_first neutral]
    positions.each{ |position|
      assert_difference('Visit.count', 1) do
        post api_destination(@destination.id), @visit.attributes.merge(force_position: position).except('id', 'quantities', 'ref'), as: :json
        assert last_response.created?, last_response.body
        visit = JSON.parse(last_response.body)
        assert_equal position, visit['force_position']
      end
    }
  end

  test 'should not create a visit with invalid position' do
    post api_destination(@destination.id), @visit.attributes.merge(force_position: 'invalid_position').except('id', 'quantities'), as: :json
    assert_equal 400, last_response.status, last_response.body
  end
end

class V01::VisitsWithJobTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActionDispatch::TestProcess

  require Rails.root.join("test/lib/devices/tomtom_base")
  include TomtomBase

  def app
    Rails.application
  end

  setup do
    @destination = destinations(:destination_one)
    @visit = visits(:visit_one)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/visits#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=#{v}" }.join('&')
  end

  def api_destination(destination_id, part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/destinations/#{destination_id}/visits#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=#{v}" }.join('&')
  end

  test 'should not create due to job' do
    assert_difference('Destination.count', 0) do
      assert_difference('Stop.count', 0) do
        post api_destination(@destination.id), @visit.attributes.except('quantities')
        assert_equal 409, last_response.status, last_response.body
      end
    end
  end

  test 'should not update a destination due to job' do
    put api_destination(@destination.id, @visit.id), @visit.attributes.except('quantities')
    assert_equal 409, last_response.status, last_response.body
  end

  test 'should not destroy a destination due to job' do
    assert_difference('Destination.count', 0) do
      delete api_destination(@destination.id, @visit.id)
      assert_equal 409, last_response.status, last_response.body
    end
  end
end
