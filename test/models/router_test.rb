require 'test_helper'
require 'routers/osrm'

class RouterTest < ActiveSupport::TestCase

  test 'should translate name' do
    begin
      I18n.default_locale = :en
      router = routers(:router_one)
      router2 = routers(:router_two)
      router3 = routers(:router_osrm)

      I18n.with_locale(:fr) do
        assert_equal router.translated_name, router.name_locale['fr']
        assert_equal router2.translated_name, router2.name_locale['en']
        assert_equal router3.translated_name, router3.name
      end

      I18n.with_locale(:en) do
        assert_equal router.translated_name, router.name_locale['en']
        assert_equal router2.translated_name, router2.name_locale['en']
        assert_equal router3.translated_name, router3.name
      end
    ensure
      I18n.default_locale = :fr
    end
  end

  test 'should pack and unpack sorted vector' do
    router = routers(:router_one)
    r = [[1, 1], [2, 2]]
    c = [[3, 3], [4, 4], [5, 5]]
    ar, ac = router.send(:pack_vector, r, c)
    assert_equal [[1, 1, 0], [2, 2, 1]], ar
    assert_equal [[3, 3, 0], [4, 4, 1], [5, 5, 2]], ac
    m = [[1, 2, 3], [4, 5, 6]]
    am = router.send(:unpack_vector, ar, ac, m)
    assert_equal m, am
  end

  test 'should pack and unpack reverse vector' do
    router = routers(:router_one)
    r = [[2, 2], [1, 1]]
    c = [[5, 5], [4, 4], [3, 3]]
    ar, ac = router.send(:pack_vector, r, c)
    assert_equal [[1, 1, 1], [2, 2, 0]], ar
    assert_equal [[3, 3, 2], [4, 4, 1], [5, 5, 0]], ac
    m = [[1, 2, 3], [4, 5, 6]]
    am = router.send(:unpack_vector, ar, ac, m)
    assert_equal [[6, 5, 4], [3, 2, 1]], am
  end

  test 'should compute matrix with OSRM' do
    Routers::Osrm.stub_any_instance(:matrix, [[0, 68212, 69314, 69167], [68257, 0, 2545, 1878], [69494, 2065, 0, 1093], [69515, 1370, 1596, 0]]) do
      router = routers(:router_osrm)
      row = [[47.3174, 5.0336]]
      column = [[45.750569, 4.839445], [45.763661, 4.851408], [45.755932, 4.850413]]
      matrix = router.matrix(row, column, 1)
      assert_equal [[[68212, 68212.0], [69167, 69167.0], [69314, 69314.0]]], matrix
    end
  end

  test 'should compute matrix with HERE' do
    Routers::Here.stub_any_instance(:matrix, lambda { |row, column, time| Array.new(row.size, Array.new(column.size, [0, 0])) }) do
      router = routers(:router_here)
      row = [[47.3174, 5.0336]]
      column = [[45.750569, 4.839445], [45.763661, 4.851408], [45.755932, 4.850413]]
      matrix = router.matrix(row, column, 1)
      assert_equal 1, matrix.size
      assert_equal 3, matrix[0].size
    end
  end

  test 'should set hash options' do
    router = routers(:router_one)
    router.options = {
        time: true,
        distance: true,
        isochrone: true,
        isodistance: true,
        avoid_zones: true,
        track: true,
        motorway: true,
        toll: true,
        trailers: true,
        weight: true,
        weight_per_axle: true,
        height: true,
        width: true,
        length: true,
        hazardous_goods: true,
        max_walk_distance: true,
        approach: true,
        snap: true,
        strict_restriction: true,
        low_emission_zone: true
    }

    router.save!

    assert router.time, true
    assert router.time?, true

    assert router.distance, true
    assert router.distance?, true

    assert router.isochrone, true
    assert router.isochrone?, true

    assert router.isodistance, true
    assert router.isodistance?, true

    assert router.avoid_zones, true
    assert router.avoid_zones?, true

    assert router.track, true
    assert router.track?, true

    assert router.motorway, true
    assert router.motorway?, true

    assert router.toll, true
    assert router.toll?, true

    assert router.trailers, true
    assert router.trailers?, true

    assert router.weight, true
    assert router.weight?, true

    assert router.weight_per_axle, true
    assert router.weight_per_axle?, true

    assert router.height, true
    assert router.height?, true

    assert router.width, true
    assert router.width?, true

    assert router.length, true
    assert router.length?, true

    assert router.hazardous_goods, true
    assert router.hazardous_goods?, true

    assert router.max_walk_distance, true
    assert router.max_walk_distance?, true

    assert router.approach, true
    assert router.approach?, true

    assert router.snap, true
    assert router.snap?, true

    assert router.strict_restriction, true
    assert router.strict_restriction?, true

    assert router.low_emission_zone, true
    assert router.low_emission_zone?, true
  end
end
