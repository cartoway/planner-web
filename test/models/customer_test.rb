require 'test_helper'

class CustomerTest < ActiveSupport::TestCase
  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |_url, _mode, _dimension, segments, _options| segments.collect { |_i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  setup do
    @customer = customers(:customer_one)
  end

  test 'should not save' do
    customer = Customer.new
    assert_not customer.save, 'Saved without required fields'
  end

  test 'should save' do
    reseller = resellers(:reseller_one)
    customer = reseller.customers.build(name: 'test', max_vehicles: 5, with_state: true,
      optimization_time: 10, optimization_minimal_time: 3, default_country: 'France',
      router: routers(:router_one), profile: profiles(:profile_one))
    assert_difference('Customer.count', 1) do
      assert_difference('Vehicle.count', 5) do
        assert_difference('Vehicle.count', 5) do
          assert_difference('VehicleUsageSet.count', 1) do
            assert_difference('DeliverableUnit.count', 1) do
              assert_difference('Store.count', 1) do
                reseller.save!
                assert_equal customer.test, false
              end
            end
          end
        end
      end
    end
  end

  test 'should validate optimization_minimal_time' do
    customer = customers(:customer_one)
    assert_raise(ActiveRecord::RecordInvalid) do
      customer.update!(optimization_minimal_time: 10, optimization_time: 2)
    end
  end

  test 'should validate router mode according to profil' do
    profile = profiles(:profile_one)
    profile.routers = Router.first(2)

    customer = Customer.new({name: 'Zorglub', max_vehicles: 2, profile: profile, router: Router.last})

    refute customer.valid?
    assert_not_empty customer.errors.messages
  end

  test 'should stop job optimizer' do
    assert_difference('Delayed::Backend::ActiveRecord::Job.count', -1) do
      @customer.job_optimizer.destroy
    end
  end

  test 'should destination add' do
    customer = customers(:customer_one)
    assert_difference('Destination.count') do
      destination = customer.destinations.build(name: 'new', city: 'Parlà')
      destination.visits.build(tags: [tags(:tag_one)])
      customer.save!
    end
  end

  test 'should update_outdated' do
    customer = customers(:customer_one)
    customer.visit_duration = '00::10:00'
    customer.plannings.each { |p|
      p.routes.select { |r| r.vehicle_usage }.each { |r|
        assert_not r.outdated
      } }
    customer.save!
    customer.plannings.each { |p|
      p.routes.select { |r| r.vehicle_usage }.each { |r|
        assert r.outdated
      } }
  end

  test 'should update_outdated for router options' do
    customer = customers(:customer_one)
    customer.weight = 20
    customer.plannings.each { |p|
      p.routes.select { |r| r.vehicle_usage }.each { |r|
        assert_not r.outdated
      } }
    customer.save!
    customer.plannings.each { |p|
      p.routes.select { |r| r.vehicle_usage }.each { |r|
        assert r.outdated
      } }
  end

  test 'should update max vehicles up' do
    assert !Planner::Application.config.manage_vehicles_only_admin
    customer = customers(:customer_one)
    assert_difference('Vehicle.count', 1) do
      assert_difference('VehicleUsage.count', customer.vehicle_usage_sets.length) do
        assert_difference('Route.count', customer.plannings.length) do
          customer.max_vehicles += 1
          customer.save!
        end
      end
    end
  end

  test 'should update max vehicles down' do
    assert !Planner::Application.config.manage_vehicles_only_admin
    customer = customers(:customer_one)
    assert_difference('Vehicle.count', -1) do
      assert_difference('VehicleUsage.count', -customer.vehicle_usage_sets.length) do
        assert_difference('Route.count', -customer.plannings.length) do
          customer.max_vehicles -= 1
          customer.save!
        end
      end
    end
  end

  test 'should create and destroy' do
    customer = @customer
    resellers(:reseller_one).save!
    assert customer.stores.size > 0
    assert customer.vehicles.size > 0
    assert customer.vehicle_usage_sets.size > 0
    assert customer.users.size > 0
    assert_difference('Customer.count', -1) do
      assert_difference('User.count', -customer.users.size) do
        customer.destroy
      end
    end
  end

  require Rails.root.join("test/lib/devices/tomtom_base")
  include TomtomBase

  test '[tomtom] change device credentials should update vehicles' do
    @customer = add_tomtom_credentials @customer
    @customer.vehicles.update_all devices: {tomtom_id: "tomtom_id"}
    @customer.update! devices: {tomtom: {account: @customer.devices[:tomtom][:account] + "_edit"} }
    assert @customer.vehicles.all? { |vehicle| !vehicle.devices[:tomtom_id] }
  end

  test '[tomtom] disable service should update vehicles' do
    @customer = add_tomtom_credentials @customer
    @customer.vehicles.update_all devices: {tomtom_id: "tomtom_id"}
    @customer.update! devices: {tomtom: {enable: false} }
    assert @customer.vehicles.all? { |vehicle| !vehicle.devices[:tomtom_id] }
  end

  require Rails.root.join("test/lib/devices/teksat_base")
  include TeksatBase

  test '[teksat] change device credentials should update vehicles' do
    @customer = add_teksat_credentials @customer
    @customer.vehicles.update_all devices: {teksat_id: "teksat_id"}
    @customer.update! devices: {teksat: {customer_id: Time.now.to_i} }
    assert @customer.vehicles.all? { |vehicle| !vehicle.devices[:teksat_id]  }
  end

  test '[teksat] disable service should update vehicles' do
    @customer = add_teksat_credentials @customer
    @customer.vehicles.update_all devices: {teksat_id: "teksat_id"}
    @customer.update! devices: {teksat: {enable: false} }
    assert @customer.vehicles.all? { |vehicle| !vehicle.devices[:teksat_id]  }
  end

  require Rails.root.join("test/lib/devices/orange_base")
  include OrangeBase

  test '[orange] change device credentials should update vehicles' do
    @customer = add_orange_credentials @customer
    @customer.vehicles.update_all devices: {orange_id: "orange_id"}
    @customer.update! devices: {orange: {username: @customer.devices[:orange][:username] + "_edit"} }
    assert @customer.vehicles.all? { |vehicle| !vehicle.devices[:orange_id]  }
  end

  test '[orange] disable service should update vehicles' do
    @customer = add_orange_credentials @customer
    @customer.vehicles.update_all devices: {orange_id: "orange_id"}
    @customer.update! devices: {orange: {enable: false} }
    assert @customer.vehicles.all? { |vehicle| !vehicle.devices[:orange_id]  }
  end

  test 'should get router dimension' do
    assert_equal 'time', @customer.router_dimension
  end

  test 'should set hash options' do
    customer = customers(:customer_two)
    customer.router_options = {
        time: true,
        distance: true,
        isochrone: true,
        isodistance: true,
        avoid_zones: true,
        track: true,
        motorway: true,
        toll: true,
        low_emission_zone: true,
        trailers: 2,
        weight: 10,
        weight_per_axle: 5,
        height: 5,
        width: 6,
        length: 30,
        hazardous_goods: 'gas',
        max_walk_distance: 200,
        approach: 'curb',
        snap: 50,
        strict_restriction: false
    }

    customer.save!

    assert_equal customer.time, true
    assert_equal customer.time?, true

    assert_equal customer.distance, true
    assert_equal customer.distance?, true

    assert_equal customer.isochrone, true
    assert_equal customer.isochrone?, true

    assert_equal customer.isodistance, true
    assert_equal customer.isodistance?, true

    assert_equal customer.avoid_zones, true
    assert_equal customer.avoid_zones?, true

    assert_equal customer.track, true
    assert_equal customer.track?, true

    assert_equal customer.motorway, true
    assert_equal customer.motorway?, true

    assert_equal customer.toll, true
    assert_equal customer.toll?, true

    assert_equal customer.low_emission_zone, true
    assert_equal customer.low_emission_zone?, true

    assert_equal customer.trailers, 2
    assert_equal customer.weight, 10
    assert_equal customer.weight_per_axle, 5
    assert_equal customer.height, 5
    assert_equal customer.width, 6
    assert_equal customer.length, 30
    assert_equal customer.hazardous_goods, 'gas'
    assert_equal customer.max_walk_distance, 200
    assert_equal customer.approach, 'curb'
    assert_equal customer.snap, 50
    assert_equal customer.strict_restriction, false
  end


  test 'customer with order array' do
    planning = plannings :planning_one
    order_array = order_arrays :order_array_one
    planning.update! order_array: order_array
    products = Product.find ActiveRecord::Base.connection.select_all("SELECT product_id FROM orders_products WHERE order_id IN (%s)" % [order_array.order_ids.join(",")]).rows
    assert products.any?
    assert planning.customer.destroy
  end

  test 'should update enable_multi_visits' do
    customer = @customer
    refs = customer.destinations.collect(&:ref)
    assert_no_difference('Destination.count') do
      assert_no_difference('Visit.count') do
        customer.enable_multi_visits = true
        customer.save
        assert_equal refs, customer.destinations.flat_map { |d| d.visits.collect(&:ref) }
        assert_equal [tags(:tag_one).label] * 4, customer.destinations.flat_map { |d| d.visits.flat_map { |v| v.tags.collect(&:label) } }
      end
    end

    customer.reload
    assert_no_difference('Destination.count') do
      assert_no_difference('Visit.count') do
        customer.enable_multi_visits = false
        customer.save
        assert_equal refs, customer.destinations.collect(&:ref)
        assert_equal [tags(:tag_one).label] * 4, customer.destinations.flat_map { |d| d.tags.collect(&:label) }
      end
    end
  end

  test 'should duplicate' do
    duplicate = nil
    unit_ids = @customer.deliverable_units.map(&:id)

    assert_difference('Customer.count', 1) do
      assert_difference('User.count', @customer.users.size) do
        assert_difference('Planning.count', @customer.plannings.size) do
          assert_difference('Destination.count', @customer.destinations.size) do
            assert_difference('Vehicle.count', @customer.vehicles.size) do
              assert_difference('Zoning.count', @customer.zonings.size) do
                assert_difference('Tag.count', @customer.tags.size) do
                  assert_difference('DeliverableUnit.count', @customer.deliverable_units.size) do
                    # assert_difference('OrderArray.count', @customer.order_arrays.size) do
                    duplicate = @customer.duplicate
                    duplicate.save!

                    assert_equal @customer.vehicles.map { |v| v.capacities.delete_if { |k, v| unit_ids.exclude? k }.values }, duplicate.vehicles.map { |v| v.capacities.values }
                    assert_equal [], @customer.vehicles.map { |v| v.capacities.delete_if { |k, v| unit_ids.exclude? k }.keys } & duplicate.vehicles.map { |v| v.capacities.keys }

                    assert_equal @customer.destinations.flat_map { |dest| dest.visits.map { |v| v.quantities.delete_if { |k, v| unit_ids.exclude? k }.values } }, duplicate.destinations.flat_map { |dest| dest.visits.map { |v| v.quantities.values } }
                    assert_equal [], @customer.destinations.flat_map { |dest| dest.visits.flat_map { |v| v.quantities.delete_if { |k, v| unit_ids.exclude? k }.keys } } & duplicate.destinations.flat_map { |dest| dest.visits.flat_map { |v| v.quantities.keys } }

                    assert duplicate.test, Planner::Application.config.customer_test_default
                    # end
                  end
                end
              end
            end
          end
        end
      end
    end

    duplicate.reload

    assert_difference('Customer.count', -1) do
      assert_difference('User.count', -@customer.users.size) do
        assert_difference('Planning.count', -@customer.plannings.size) do
          assert_difference('Destination.count', -@customer.destinations.size) do
            assert_difference('Vehicle.count', -@customer.vehicles.size) do
              assert_difference('Zoning.count', -@customer.zonings.size) do
                assert_difference('Tag.count', -@customer.tags.size) do
                  assert_difference('DeliverableUnit.count', -@customer.deliverable_units.size) do
                    # assert_difference('OrderArray.count', -@customer.order_arrays.size) do
                    duplicate.destroy!
                    # end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test 'should duplicate without outdated routes' do
    duplicated_customer = nil

    assert_difference('Customer.count', 1) do
      duplicated_customer = @customer.duplicate
      routes = duplicated_customer.plannings.map(&:routes).flatten

      assert_equal(0, routes.count(&:outdated))
    end

    duplicated_customer.destroy!
  end

  test 'should cascade delete destination, visits, stops' do
    without_loading Stop do
      without_loading Visit do
        assert_difference('Stop.count', -6) do
          assert_difference('Visit.count', -4) do
            @customer.destinations.delete_all
          end
        end
      end
    end
  end

  test 'should clear all destinations and outdate routes' do
    # TODO: activate code when without_loading can be called inside another without_loading with options
    # without_loading Stop, if: -> (stop) { o = !stop.is_a?(StopRest); } do
      without_loading Visit do
        assert_difference('Stop.count', -6) do
          assert_difference('Visit.count', -4) do
            @customer.delete_all_destinations
          end
        end
      end
    # end
    assert plannings(:planning_one).routes.all? { |r| r.outdated }
  end

  test 'should clear all visits and outdate routes' do
    without_loading Stop, if: -> (stop) { !stop.is_a?(StopRest) } do
      assert_difference('Stop.count', -6) do
        assert_difference('Visit.count', -4) do
          @customer.delete_all_visits
        end
      end
    end
    assert plannings(:planning_one).routes.all? { |r| r.outdated }
  end

  test 'should use limitation' do
    @customer.delete_all_destinations
    @customer.plannings.delete_all
    @customer.zonings.delete_all
    @customer.vehicle_usage_sets[1..-1].each{ |c| @customer.vehicle_usage_sets.destroy(c) }

    @customer.max_plannings = 1
    @customer.max_destinations = 1
    @customer.max_zonings = 1
    @customer.max_vehicle_usage_sets = 2
    @customer.save!

    assert_difference('Destination.count', 1) do
      @customer.destinations.build(name: 'plop', city: 'Bordeaux', state: 'Midi-Pyrénées')
      @customer.save!
    end

    assert_difference('Destination.count', 0) do
      @customer.destinations.build(name: 'plop', city: 'Bordeaux', state: 'Midi-Pyrénées')
      begin
        @customer.save!
        fail
      rescue
        # Should not save
      end
    end

    @customer.reload
    assert_difference('Planning.count', 1) do
      @customer.plannings.build(name: 'plop', vehicle_usage_set: @customer.vehicle_usage_sets.first)
      @customer.save!
    end

    assert_difference('Planning.count', 0) do
      @customer.plannings.build(name: 'plop', vehicle_usage_set: @customer.vehicle_usage_sets.first)
      begin
        @customer.save!
        fail
      rescue
        # Should not save
      end
    end

    @customer.reload
    assert_difference('Zoning.count', 1) do
      @customer.zonings.build(name: 'plop')
      @customer.save!
    end

    assert_difference('Zoning.count', 0) do
      @customer.zonings.build(name: 'plop')
      begin
        @customer.save!
        fail
      rescue
        # Should not save
      end
    end

    @customer.reload
    assert_difference('VehicleUsageSet.count', 1) do
      @customer.vehicle_usage_sets.build(name: 'plop')
      @customer.save!
    end

    assert_difference('VehicleUsageSet.count', 0) do
      @customer.vehicle_usage_sets.build(name: 'plop')
      begin
        @customer.save!
        fail
      rescue
        # Should not save
      end
    end
  end

  test "should outdate all customer's routes" do
    @customer.update(optimization_force_start: true)
    assert_equal [[true, true, true], [true, true, true]], @customer.plannings.collect{ |p| p.routes.collect(&:outdated) }
  end

  test 'should not load plans on enable multi-visits' do
    without_loading Planning do
      without_loading Route do
        @customer.update_attribute(:enable_multi_visits, !@customer.enable_multi_visits)
      end
    end
  end

  test 'should not load routes when updating plans' do
    without_loading Route do
      @customer.plannings.each_with_index do |p, i|
        p.zoning_outdated = true if i == 0
      end
      @customer.save!
    end
  end

  test 'should allow and update advanced options with special characters' do
    options = {
      'import' => {
        'destinations' => {
          'spreadsheetColumnsDef' => {
            'ref' => "Test/string&is#testing'~\"{([|^@])} œéèêùà\\!@#S%^*+_-?/<>:';",
            'name' => '<>my _ name0123456789',
            'ref_visit' => 'ref visit  '
          }
        }
      }
    }
    assert @customer.update advanced_options: options
    assert_equal options, @customer.advanced_options
  end
end
