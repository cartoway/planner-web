require 'test_helper'

class V01::ZoningsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @zoning = zonings(:zoning_one)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/zonings#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should return customer''s zonings' do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @zoning.customer.zonings.size, JSON.parse(last_response.body).size
  end

  test 'should return customer''s zonings by ids' do
    get api(nil, 'ids' => @zoning.id)
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
    assert_equal @zoning.id, JSON.parse(last_response.body)[0]['id']
  end

  test 'should return a zoning' do
    get api(@zoning.id)
    assert last_response.ok?, last_response.body
    assert_equal @zoning.name, JSON.parse(last_response.body)['name']
  end

  test 'should create a zoning' do
    assert_difference('Zoning.count', 1) do
      @zoning.name = 'new name'
      post api(), @zoning.attributes
      assert last_response.created?, last_response.body
    end
  end

  test 'should create a zoning with dumped multipolygon' do
    assert_difference('Zoning.count', 1) do
      zoning = zonings(:zoning_four)
      post api(), zoning.attributes.merge(zones: [zoning.zones.first.attributes])
      assert last_response.created?, last_response.body
      zoning_params = JSON.parse(last_response.body)
      assert_equal zoning.zones.size + 2, zoning_params['zones'].size
    end
  end

  test 'should create a zoning with dumped geometrycollection' do
    assert_difference('Zoning.count', 1) do
      zoning = zonings(:zoning_five)
      post api(), zoning.attributes.merge(zones: [zoning.zones.first.attributes])
      assert last_response.created?, last_response.body
      zoning_params = JSON.parse(last_response.body)
      assert_equal 1, zoning_params['zones'].size
    end
  end

  test 'should update a zoning' do
    @zoning.name = 'new name'
    put api(@zoning.id), @zoning.attributes
    assert last_response.ok?, last_response.body

    get api(@zoning.id)
    assert last_response.ok?, last_response.body
    assert_equal @zoning.name, JSON.parse(last_response.body)['name']
  end

  test 'should destroy a zoning' do
    assert_difference('Zoning.count', -1) do
      delete api(@zoning.id)
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy multiple zonings' do
    assert_difference('Zoning.count', -2) do
      delete api + "&ids=#{zonings(:zoning_one).id},#{zonings(:zoning_two).id}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should generate zoning from planning' do
    patch api("#{@zoning.id}/from_planning/#{plannings(:planning_one).id}")
    assert last_response.ok?, last_response.body
    assert_equal @zoning.name, JSON.parse(last_response.body)['name']
  end

  test 'should generate zoning automatically' do
    patch api("#{@zoning.id}/automatic/#{plannings(:planning_one).id}")
    assert last_response.ok?, last_response.body
    assert_equal @zoning.name, JSON.parse(last_response.body)['name']
  end

  test 'should generate isochrone and isodistance' do
    store_one = stores(:store_one)
    [:isochrone, :isodistance].each{ |isowhat|
        begin
          uri_template = Addressable::Template.new('http://localhost:5000/0.1/isoline.json')
          stub_table = stub_request(:post, uri_template)
            .with(:body => hash_including(dimension: (isowhat == :isochrone ? 'time' : 'distance'), loc: "#{store_one.lat},#{store_one.lng}", mode: 'car', size: '5'))
            .to_return(status: 200, body: File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/isochrone/isochrone-1.json').read)
          patch api("#{@zoning.id}/" + isowhat.to_s, vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id, size: 5)
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body)['zones'].length
          assert_not_nil JSON.parse(last_response.body)['zones'][0]['polygon']
        ensure
          remove_request_stub(stub_table)
        end
      }
  end

  test 'should generate isochrone and isodistance with name according to unit' do
    store_one = stores(:store_one)
    [:km, :mi].each{ |unit|
        begin
          uri_template = Addressable::Template.new('http://localhost:5000/0.1/isoline.json')
          stub_table = stub_request(:post, uri_template)
          .with(:body => hash_including(dimension: 'distance', loc: "#{store_one.lat},#{store_one.lng}", mode: 'car', size: '10000'))
          .to_return(status: 200, body: File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/isochrone/isochrone-1.json').read)
          users(:user_one).update prefered_unit: :unit
          patch api("#{@zoning.id}/isodistance", vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id, size: 10000)
          assert last_response.ok?, last_response.body
          assert_equal "Isodistance "+ (unit == 'km' ? '10 km' : '6.21 miles') + " depuis " + store_one.name, JSON.parse(last_response.body)['zones'][0]['name']
        ensure
          remove_request_stub(stub_table)
        end
      }
  end

  test 'should generate isochrone and isodistance for one vehicle' do
    store_one = stores(:store_one)
    [:isochrone, :isodistance].each{ |isowhat|
      begin
        uri_template = Addressable::Template.new('http://localhost:5000/0.1/isoline.json')
        stub_table = stub_request(:post, uri_template)
          .with(:body => hash_including(dimension: (isowhat == :isochrone ? 'time' : 'distance'), loc: "#{store_one.lat},#{store_one.lng}", mode: 'car', size: '5'))
          .to_return(status: 200, body: File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/isochrone/isochrone-1.json').read)
        patch api("#{@zoning.id}/vehicle_usage/" + vehicle_usages(:vehicle_usage_one_one).id.to_s + "/" + isowhat.to_s, size: 5)
        assert last_response.ok?, last_response.body
        assert_not_nil JSON.parse(last_response.body)['polygon']
      ensure
        remove_request_stub(stub_table)
      end
    }
  end

  test 'should generate an isochrone zone' do
    store_one = stores(:store_one)
    [:isochrone, :isodistance].each { |isowhat|
      begin
        uri_template = Addressable::Template.new('http://localhost:5000/0.1/isoline.json')
        stub_table = stub_request(:post, uri_template)
          .with(:body => hash_including(dimension: (isowhat == :isochrone ? 'time' : 'distance'), loc: "#{store_one.lat},#{store_one.lng}", mode: 'car', size: '10'))
          .to_return(status: 200, body: File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/isochrone/isochrone-1.json').read)
        patch api(isowhat.to_s, {lat: store_one.lat.to_s, lng: store_one.lng.to_s, size: 10})
        assert last_response.ok?, last_response.body
      ensure
        remove_request_stub(stub_table)
      end
    }
  end

  test 'should return destinations by zone' do
    get api("#{@zoning.id}/destinations")
    assert last_response.ok?, last_response.body
    zoning_destinations = JSON.parse(last_response.body)
    assert_not_nil zoning_destinations
    assert_equal @zoning.id, zoning_destinations['id']
    assert_equal 1, zoning_destinations['zones'][0]['destinations'].size
  end

  test 'should return if a point is inside a polygone' do
    # Check for coordinates inside zone
    get api("#{@zoning.id}/polygon_by_point", 'lat' => 49.23123, 'lng' => -0.335083)
    assert last_response.ok?, last_response.body
    assert_not_nil JSON.parse(last_response.body)

    # Check for coordinates outside all zones
    get api("#{@zoning.id}/polygon_by_point", 'lat' => 42.23123, 'lng' => -3.335083)
    assert_equal 204, last_response.status
  end

  test 'should use limitation' do
    customer = @zoning.customer
    customer.zonings.delete_all
    customer.max_zonings = 1
    customer.save!

    assert_difference('Zoning.count', 1) do
      @zoning.name = 'new name 1'
      post api(), @zoning.attributes
      assert last_response.created?, last_response.body
    end

    assert_difference('Zoning.count', 0) do
      assert_difference('Zone.count', 0) do
        @zoning.name = 'new name 2'
        post api(), @zoning.attributes
        assert last_response.forbidden?, last_response.body
        assert_equal 'dépassement du nombre maximal de sectorisations', JSON.parse(last_response.body)['message']
      end
    end
  end
end
