require 'test_helper'

class ZoningTest < ActiveSupport::TestCase

  test 'should not save' do
    zoning = Zoning.new
    assert_not zoning.save, 'Saved without required fields'
  end

  test 'should inside' do
    zoning = zonings(:zoning_one)
    assert zoning.inside(destinations(:destination_one))
    assert_not zoning.inside(destinations(:destination_two))
  end

  test 'should apply' do
    zoning = zonings(:zoning_one)
    assert_equal(
      {nil => [visits(:visit_two)], zones(:zone_one) => [visits(:visit_one)]},
      zoning.apply([visits(:visit_one), visits(:visit_two)]))
  end

  test 'should dup' do
    zoning = zonings(:zoning_one)
    oo = zoning.duplicate
    assert oo.zones[0].zoning == oo
  end

  test 'should flag_outdated' do
    zoning = zonings(:zoning_one)
    assert_not zoning.plannings[0].zoning_outdated
    zoning.flag_outdated
    assert zoning.plannings[0].zoning_outdated
  end

  test 'should generate automatic clustering' do
    zoning = zonings(:zoning_one)
    zoning.automatic_clustering(plannings(:planning_one), 2)
    assert 2, zoning.zones.size
  end

  test 'should generate automatic clustering with disabled vehicles' do
    planning = plannings(:planning_one)
    planning.vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_three)
    zoning = zonings(:zoning_one)
    zoning.automatic_clustering(planning, 2)
    assert 1, zoning.zones.size
  end

  test 'should generate automatic clustering with/without out_of_route' do
    customer = customers :customer_one
    planning = plannings :planning_one
    assert planning.routes.find{ |route| !route.vehicle_usage }.stops.exists?
    destinations(:destination_unaffected_one).update(lat: -45, lng: 2)
    geometries = nil
    zoning = customer.zonings.new
    [true, false].each { |out_of_route|
      zoning.automatic_clustering planning, nil, out_of_route
      assert_equal customer.vehicles.count, zoning.zones.length
      if !geometries
        geometries = zoning.zones.map(&:polygon).join(',')
      else
        assert_not_equal geometries, zoning.zones.map(&:polygon).join(',')
      end
    }
  end

  test 'should generate from planning' do
    zoning = zonings :zoning_one
    planning = plannings :planning_one
    zoning.from_planning(planning)
    assert_equal planning.routes.select(&:vehicle_usage_id).count, zoning.zones.length
  end

  test 'should generate isochrones' do
    begin
      # TODO: An undefined test changes time zone...
      # .with(:body => hash_including(size: '5', mode: 'car', traffic: 'true', weight: '10', departure: Date.today.strftime('%Y-%m-%d') + ' 10:00:00 UTC'))
      stub_isochrone = stub_request(:post, 'http://localhost:5000/0.1/isoline.json')
        .with(:body => hash_including(size: '5', mode: 'car', traffic: 'true', weight: '10', departure: Date.today.strftime('%Y-%m-%d') + ' 10:00:00 ' + (Time.zone.now.strftime('%z') == '+0000' ? 'UTC' : (Time.zone.now.strftime('%z')))))
        .to_return(status: 200, body: File.new(File.expand_path('../../web_mocks/', __FILE__) + '/isochrone/isochrone-1.json').read)
      zoning = zonings(:zoning_one)
      zoning.isochrones(5, zoning.customer.vehicle_usage_sets[0], Date.today)
      assert_equal zoning.customer.vehicle_usage_sets[0].vehicle_usages.select(&:active).count, zoning.zones.length
    ensure
      remove_request_stub(stub_isochrone) if stub_isochrone
    end
  end

  test 'should raise error with self intersecting collection' do
    zoning = zonings(:zoning_one)
    zone = Zone.new(
      zoning_id: zoning.id,
      polygon: {
        'type': 'Feature',
        'geometry': {
          'type' => 'GeometryCollection',
          'geometries' => [
            {
              'type' => 'Polygon',
              'coordinates' => [
                [
                  [0, 0],
                  [1, 1],
                  [2, 2],
                  [0, 0]
                ]
              ]
            },
            {
              'type' => 'Polygon',
              'coordinates' => [
                [
                  [3, 3],
                  [4, 4],
                  [5, 5],
                  [3, 3]
                ]
              ]
            }
          ]
        }
      }.to_json
    )
    assert_raises(Exceptions::PolygonValidityError) { zoning.zones << zone }
  end
end
