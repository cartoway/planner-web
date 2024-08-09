require 'test_helper'
require 'set'

class ProfilesHelperTest < ActionView::TestCase
  setup do
    @profile = profiles(:profile_one)
    @profile2 = profiles(:profile_two)
    @routers = Router.all
    @profile.routers = @routers

    @layers = Layer.all
    @profile.layers = @layers
  end

  test 'routers by profile should return a hash' do
    assert_kind_of Hash, routers_by_profile
  end

  test 'routers by profile should contains routers belonging to profiles' do
    h = {@profile.id => @routers.map{ |r| [r.id, r.time?, r.distance?]}, @profile2.id => @profile2.routers.map{ |r| [r.id, r.time?, r.distance?]}}

    assert_equal h, routers_by_profile
  end

  test 'format routers by profile know time and/or distance mode' do
    @profile2.routers = @routers.select{ |router| router.name == 'MyString' }

    h = ["#{@profile2.routers.second.id}_distance", "#{@profile2.routers.second.id}_time", "#{@profile2.routers.first.id}_time"]

    assert Set.new(h) == Set.new(routers_modes_by_profile[@profile2.id])
  end

  test 'layers by profile should contains layers belongign to profiles' do
    h = {@profile.id => @layers.pluck(:id), @profile2.id => @profile2.layers.pluck(:id)}

    assert_kind_of Hash, layers_by_profile
    assert_equal h, layers_by_profile
  end
end
