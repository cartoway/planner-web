require 'test_helper'

require 'rexml/document'
include REXML

class PlanningsControllerTest < ActionController::TestCase

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @planning = plannings(:planning_one)
    sign_in users(:user_one)
    customers(:customer_one).update(job_optimizer_id: nil, job_destination_geocoding_id: nil)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda{ |url, mode, dimensions, row, column, options| [Array.new(row.size) { Array.new(column.size, 0) }] }) do
        # return all services in reverse order in first route, rests at the end
        OptimizerWrapper.stub_any_instance(:optimize, lambda { |planning, routes, options|
        # Put all the stops on the first available route with a vehicle
          returned_stops = routes.flat_map{ |r| r.stops.select{ |stop| stop.is_a?(StopVisit) }}
          first_route = routes.find{ |r| r.vehicle_usage? }
          first_route_rests = first_route.stops.select{ |stop| stop.is_a?(StopRest) }.compact
          (
            routes.select{ |r| !r.vehicle_usage? }.map{ |r| [r.id, []] } +
            routes.select{ |r| r.vehicle_usage? }.map.with_index{ |r, i| [r.id, ((i.zero? ? returned_stops.reverse : []) + first_route_rests).map(&:id)] }.uniq
          ).to_h
        }) do
          yield
        end
      end
    end
  end

  test 'user can only view plannings from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @planning
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @planning

    get :edit, params: { id: plannings(:planning_three) }
    assert_response :not_found
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:plannings)
    assert_valid response
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'Create Planning' do
    orig_locale = I18n.locale
    begin
      # EN
      I18n.locale = I18n.default_locale = :en
      assert_equal :en, I18n.locale
      assert_difference('Planning.count') do
        post :create, params: { planning: { name: @planning.name, vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id, zoning_ids: @planning.zonings.collect(&:id), date: '10-30-2016' } }
      end
      assert_redirected_to edit_planning_path(assigns(:planning))
      assert assigns(:planning).persisted?
      assert assigns(:planning).date.strftime("%d-%m-%Y") == '30-10-2016'

      # FR
      I18n.locale = I18n.default_locale = :fr
      assert_equal :fr, I18n.locale
      assert_difference('Planning.count') do
        post :create, params: { planning: { name: @planning.name, vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id, zoning_ids: @planning.zonings.collect(&:id), date: '30-10-2016' } }
      end
      assert_redirected_to edit_planning_path(assigns(:planning))
      assert assigns(:planning).persisted?
      assert assigns(:planning).date.strftime("%d-%m-%Y") == '30-10-2016'
    ensure
      I18n.locale = I18n.default_locale = orig_locale
    end
  end

  test 'Create Planning with selected tag operation' do
    sign_in users(:user_three) # to use customer_two
    planning = plannings(:planning_four)

    assert_difference('Planning.count') do
      post :create, params: { planning: { name: planning.name, vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_two).id, zoning_ids: planning.zonings.collect(&:id), tag_operation: '_and', tag_ids: [tags(:tag_three).id, tags(:tag_four).id] } }
    end
    assert assigns(:planning).persisted?
    assert_redirected_to edit_planning_path(assigns(:planning))
    # Check number of visits (including both tags) associated to the new planning
    assert_equal 1, assigns(:planning).visits_compatibles.count
    # Check number of stops (including both tags) in the new planning
    assert_equal 1, assigns(:planning).routes[0].stops.size

    assert_difference('Planning.count') do
      post :create, params: { planning: { name: planning.name, vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_two).id, zoning_ids: planning.zonings.collect(&:id), tag_operation: '_or', tag_ids: [tags(:tag_three).id, tags(:tag_four).id] } }
    end
    assert assigns(:planning).persisted?
    assert_redirected_to edit_planning_path(assigns(:planning))
    # Check number of visits (including both tags) associated to the new planning
    assert_equal 2, assigns(:planning).visits_compatibles.count
    # Check number of stops (including both tags) in the new planning
    assert_equal 2, assigns(:planning).routes[0].stops.size
  end

  test 'Create Planning with begin and end date' do
    assert_difference('Planning.count') do
      post :create, params: { planning: { name: @planning.name, vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id, zoning_ids: @planning.zonings.collect(&:id), begin_date: '20-04-2017', end_date: '25-04-2017', active: false } }
    end
    assert_redirected_to edit_planning_path(assigns(:planning))
    assert assigns(:planning).persisted?
    assert !assigns(:planning).active
    assert assigns(:planning).begin_date.strftime('%d-%m-%Y') == '20-04-2017'
    assert assigns(:planning).end_date.strftime('%d-%m-%Y') == '25-04-2017'
  end

  test 'Update Planning' do
    orig_locale = I18n.locale
    begin
      # EN
      I18n.locale = I18n.default_locale = :en
      assert_equal :en, I18n.locale
      patch :update, params: { id: @planning, planning: { name: @planning.name, zoning_ids: @planning.zonings.collect(&:id), date: '10-30-2016' } }
      assert_redirected_to edit_planning_path(assigns(:planning))
      assert assigns(:planning).persisted?
      assert assigns(:planning).date.strftime("%d-%m-%Y") == '30-10-2016'

      # FR
      I18n.locale = I18n.default_locale = :fr
      assert_equal :fr, I18n.locale
      patch :update, params: { id: @planning, planning: { name: @planning.name, zoning_ids: @planning.zonings.collect(&:id), date: '30-10-2016' } }
      assert_redirected_to edit_planning_path(assigns(:planning))
      assert assigns(:planning).persisted?
      assert assigns(:planning).date.strftime("%d-%m-%Y") == '30-10-2016'
    ensure
      I18n.locale = I18n.default_locale = orig_locale
    end
  end

  test 'should not create planning' do
    assert_difference('Planning.count', 0) do
      post :create, params: { planning: { name: '', vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id } }
    end

    assert_template :new
    planning = assigns(:planning)
    assert planning.errors.any?
    assert_valid response
  end

  test 'should show planning' do
    get :show, params: { id: @planning }
    assert_response :success
    assert_valid response
  end

  test 'should show planning as json' do
    get :show, params: { format: :json, id: @planning }
    assert_response :success
    assert_equal 3, JSON.parse(response.body)['routes'].size
  end

  test 'should show only some routes from planning' do
    get :show, params: { format: :json, id: @planning, route_ids: "#{routes(:route_one_one).id},#{routes(:route_three_one).id}" }
    assert_response :success
    assert_equal 2, JSON.parse(response.body)['routes'].size
  end

  test 'should show planning without loading stops' do
    without_loading Stop do
      get :show, params: { format: :json, id: @planning, with_stops: false }
      assert_response :success
    end
  end

  test 'should show planning as excel' do
    get :show, params: { id: @planning, format: :excel }
    assert_response :success
  end

  test 'should show planning without date as excel' do
    @planning.update(date: nil)
    get :show, params: { id: @planning, format: :excel }
    assert_response :success
  end

  test 'should export and import with ref' do
    # Fix INVALID fixtures
    stops(:stop_three_one).destroy
    # Remove duplicate in ref
    destinations(:destination_three).update ref: 'd'
    # Activate all vehicles (first vehicle_usage_set is random)
    customers(:customer_one).vehicle_usage_sets[0].vehicle_usages.each{ |vu| vu.update active: true }

    get :show, params: { id: @planning, format: :csv }
    assert_response :success
    tempfile = Tempfile.new('text.csv')
    tempfile.write(response.body)
    tempfile.rewind
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: tempfile,
    })
    file.original_filename = 'text.csv'

    assert_no_difference('Planning.count') do
      import = ImportCsv.new(importer: ImporterDestinations.new(customers(:customer_one)), replace: false, file: file)
      assert import.import, import.errors.messages
    end
  end

  test 'should export and import without ref' do
    # Fix INVALID fixtures
    stops(:stop_three_one).destroy
    # Remove duplicate in ref
    destinations(:destination_three).update ref: 'd'
    # Activate all vehicles (first vehicle_usage_set is random)
    customers(:customer_one).vehicle_usage_sets[0].vehicle_usages.each{ |vu| vu.update active: true }
    # Remove ref
    @planning.update! ref: nil

    get :show, params: { id: @planning, format: :csv }
    assert_response :success
    tempfile = Tempfile.new('text.csv')
    tempfile.write(response.body)
    tempfile.rewind
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: tempfile,
    })
    file.original_filename = 'text.csv'

    assert_difference('Planning.count', 1) do
      import = ImportCsv.new(importer: ImporterDestinations.new(customers(:customer_one)), replace: false, file: file)
      assert import.import, import.errors.messages
    end
  end

  test 'should show planning as csv with order array' do
    order_array = order_arrays(:order_array_one)
    @planning.apply_orders(order_array, 0)
    @planning.save!

    get :show, params: { id: @planning, format: :csv }
    assert_response :success
    assert_equal 'r1,planning1,10/10/2014,,,,visite,,,,,,"","","","","","","","",,,,a,unaffected_one,MyString,MyString,MyString,MyString,,1.5,1.5,MyString,MyString,tag1,a,00:01:00,10:00,11:00,,,,neutre,tag1,', response.body.split("\n")[1]
    assert_equal 'r1,planning1,10/10/2014,route_one,001,1,visite,1,,00:00,1.1,,"","","","","","","","",,,,b,destination_one,Rue des Lilas,MyString,33200,Bordeau,,49.1857,-0.3735,MyString,MyString,"",b,00:05:33,10:00,11:00,,,4,neutre,tag1,P1/P2', response.body.split("\n").select{ |l| l.include?('001') }[1]
  end

  test "it shouldn't have special char in ref routes when using vehicle name" do
    # Override all vehicle names
    Vehicle.all.each do |v|
      v.name = 'vehicle;!,;.*'
      v.save!
    end

    # Delete all routes refs
    Route.all.each do |route|
      route.ref = nil
      route.save!
    end

    get :show, params: { id: @planning, format: :csv }
    assert_response :success
    assert_equal 'r1,planning1,10/10/2015,vehicle      ,003,0,site,,,07:00,0,0,,,,,,,,,,,,,store nogeo,MyString,,MyString,MyString,,,,,,,,,,,,,,,,', response.body.split("\n")[2]
  end

  test 'should show planning as csv with ordered columns' do
    get :show, params: { id: @planning, format: :csv, stops: 'visit', columns: 'route|name|street|postalcode|city' }
    assert_response :success
    assert_equal 'route_three,destination_one,Rue des Lilas,33200,Bordeau', response.body.split("\n")[1]
  end

  test 'should show planning as gpx' do
    get :show, params: { id: @planning, format: :gpx }
    assert_response :success
    assert Document.new(response.body)
  end

  test 'should show planning as kml' do
    get :show, params: { id: @planning, format: :kml }
    assert_response :success
    assert Document.new(response.body)
  end

  test 'should show planning as kmz' do
    get :show, params: { id: @planning, format: :kmz }
    assert_response :success
  end

  test 'should show planning as kmz by email' do
    get :show, params: { id: @planning, format: :kmz, email: 1 }
    assert_response :success
  end

  test 'should get edit' do
    without_loading Stop do
      get :edit, params: { id: @planning }
      assert_response :success
      assert_valid response
    end
  end

  test 'should update planning and change zoning' do
    patch :update, params: { id: @planning, planning: { zoning_id: zonings(:zoning_two).id } }
    assert_redirected_to edit_planning_path(assigns(:planning))
  end

  test 'should not update planning' do
    patch :update, params: { id: @planning, planning: { name: '' } }

    assert_template :edit
    planning = assigns(:planning)
    assert planning.errors.any?
    assert_valid response
  end

  test 'should destroy planning' do
    assert_difference('Planning.count', -1) do
      delete :destroy, params: { id: @planning }
    end

    assert_redirected_to plannings_path
  end

  test 'should destroy multiple planning' do
    assert_difference('Planning.count', -2) do
      delete :destroy_multiple, params: { plannings: { plannings(:planning_one).id => 1, plannings(:planning_two).id => 1 } }
    end

    assert_redirected_to plannings_path
  end

  test 'should move' do
    without_loading Stop, if: -> (obj) { obj.route_id != @planning.routes[0].id && obj.route_id != @planning.routes[1].id } do
      patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_id: @planning.routes[0].stops[0], index: 1, format: :json }
      assert_response :success
      assert_equal 2, JSON.parse(response.body)['routes'].size
      @planning.routes.select(&:vehicle_usage).each{ |vu|
        assert_not vu.outdated
      }
    end
  end

  test 'should move many stops' do
    stop_ids = @planning.routes.reject { |ro| ro.id == @planning.routes[1].id }.flat_map { |ro| ro.stops.map(&:id) }
    patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_ids: stop_ids, format: :json }
    assert_response :success
    assert_equal 3, JSON.parse(response.body)['routes'].size
    @planning.routes.select(&:vehicle_usage).each{ |vu|
      assert_not vu.outdated
    }
  end

  test 'can move many stops at the start of planning' do
    moving_stop_ids = @planning.routes.reject { |route| route.id == @planning.routes[1].id }.flat_map { |route| route.stops.pluck(:id) }

    patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_ids: moving_stop_ids, index: '1', format: :json }

    assert_response :success

    JSON.parse(response.body)['routes'][0]['stops'][0,4].each do |stop|
      assert moving_stop_ids.include?(stop['stop_id'])
      assert (1..5).include?(stop['stop_index'])
    end
  end

  test 'can move many stops at the end of planning' do
    moving_stop_ids = @planning.routes.reject { |route| route.id == @planning.routes[1].id }.flat_map { |route| route.stops.pluck(:id) }

    patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_ids: moving_stop_ids, index: '-1', format: :json }

    assert_response :success

    JSON.parse(response.body)['routes'][0]['stops'][2,7].each do |stop|
      assert moving_stop_ids.include?(stop['stop_id'])
      assert (3..6).include?(stop['stop_index'])
    end
  end

  test 'should not move with error' do
    ApplicationController.stub_any_instance(:server_error, lambda { |*a| raise }) do
      Route.stub_any_instance(:compute, lambda { |*a| raise }) do
        assert_no_difference('Stop.count') do
          assert_raise do
            patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_id: @planning.routes[0].stops[0], index: 1, format: :json }
            assert_valid response
            assert_response 422
          end
        end
      end
    end
  end

  test 'should move with automatic index' do
    patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_id: @planning.routes[0].stops[0], format: :json }
    assert_response :success
    assert_equal 2, JSON.parse(response.body)['routes'].size
  end

  test 'should not move' do
    assert_no_difference('Stop.count') do
      patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_id: @planning.routes[0].stops[0], index: 666, format: :json }
      assert_valid response
      refute_empty JSON.parse(response.body)['error']
      assert_response 422
    end
  end

  test 'should not move stop to route with deactivated vehicle' do
    route = @planning.routes.joins(:vehicle_usage).take
    route.vehicle_usage.update! active: !route.vehicle_usage.active?
    out_of_route = @planning.routes.detect{|route| !route.vehicle_usage }
    stop = out_of_route.stops.take
    ApplicationController.stub_any_instance(:server_error, lambda { |*a| raise }) do
      assert_raises do
        patch :move, params: { planning_id: @planning.id, route_id: route.id, stop_id: stop.id, index: 1, format: :json }
      end
    end
    assert stop.reload.route == out_of_route
  end

  test 'should refresh' do
    get :refresh, params: { planning_id: @planning, format: :json }
    assert_response :success
  end

  test 'should apply none zoning' do
    @planning.zoning_outdated = true
    @planning.save!
    stop_ids = @planning.routes.flat_map{ |r| r.stop_ids }
    assert_no_difference('Stop.count') do
      patch :apply_zonings, params: { id: @planning, format: :json }
      assert_response :success
      planning = assigns(:planning)
      assert_not planning.zoning_outdated
      assert_equal [], planning.zonings.map(&:id)
      assert_equal stop_ids, planning.routes.flat_map{ |r| r.stop_ids }
    end
  end

  test 'should apply zoning' do
    @planning.zoning_outdated = true
    @planning.save!
    stop_ids = @planning.routes.flat_map{ |r| r.stop_ids }
    assert_no_difference('Stop.count') do
      patch :apply_zonings, params: { id: @planning, format: :json, planning: { zoning_ids: [zonings(:zoning_one).id] } }
      assert_response :success
      planning = assigns(:planning)
      assert_not planning.zoning_outdated
      assert_equal [zonings(:zoning_one).id], planning.zonings.map(&:id)
      assert_not_equal stop_ids, planning.routes.flat_map{ |r| r.stop_ids }
    end
  end

  test 'should switch with same vehicle' do
    patch :switch, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, vehicle_usage_id: vehicle_usages(:vehicle_usage_one_one).id }
    assert_response :success, id: @planning
    assert_equal 1, JSON.parse(response.body)['routes'].size
    @planning.reload
    @planning.routes.select(&:vehicle_usage).each{ |r|
      assert_equal 1, r.stops.select{ |s| s.is_a?(StopRest) }.size
      assert_not r.outdated
    }
  end

  test 'should switch' do
    @planning.routes.each(&:compute!) # To get correct colors for linestrings

    without_loading Stop, if: -> (obj) { obj.route_id != @planning.routes[1].id && obj.route_id != @planning.routes[2].id } do
      assert_equal 0, JSON.parse(@planning.to_geojson)['features'].select{ |f|
        f['geometry']['type'] == 'LineString' && f['properties']['color'] == '#00FF00'
      }.size

      patch :switch, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, vehicle_usage_id: vehicle_usages(:vehicle_usage_one_three).id }
      assert_response :success, id: @planning
      assert_equal 2, JSON.parse(response.body)['routes'].size
      @planning.reload
      @planning.routes.select(&:vehicle_usage).each{ |r|
        assert_equal 1, r.stops.select{ |s| s.is_a?(StopRest) }.size
      }
      assert_equal 2, JSON.parse(@planning.to_geojson)['features'].select{ |f|
        f['geometry']['type'] == 'LineString' && f['properties']['color'] == '#00FF00'
      }.size
    end
  end

  test 'should not switch' do
    ApplicationController.stub_any_instance(:not_found_error, lambda { |*a| raise ActiveRecord::RecordNotFound }) do
      assert_raises ActiveRecord::RecordNotFound do
        patch :switch, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, vehicle_usage_id: 666 }
      end
    end
  end

  test 'should update stop' do
    without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_one_one).id } do
      patch :update_stop, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, stop_id: stops(:stop_one_one).id, stop: { active: false } }
      assert_response :success
      assert_equal 1, JSON.parse(response.body)['routes'].size
      assert_not JSON.parse(response.body)['routes'][0][:outdated]
    end
  end

  test 'should not update stop with error' do
    Route.stub_any_instance(:compute!, lambda { |*a| raise }) do
      stop = stops(:stop_one_one)
      assert_raise do
        patch :update_stop, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, stop_id: stop.id, stop: { active: false } }
        assert_valid response
        assert_response 422
      end
      assert stop.reload.active
    end
  end

  test 'should optimize one route in planning' do
    get :optimize_route, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body['routes'].size
    assert_equal 2, body.dig('averages', 'vehicles')
  end

  test 'should optimize all routes in planning' do
    get :optimize, params: { planning_id: @planning, format: :json, global: true }
    assert_response :success
    assert_equal @planning.routes.size, JSON.parse(response.body)['routes'].size
  end

  test 'should optimize planning with overload_multiplier options' do
    overload_multipliers = {}
    @planning.customer.deliverable_units.each_with_index{ |du, index| overload_multipliers[index] = {unit_id: du.id, ignore: true}}
    get :optimize, params: { planning_id: @planning, format: :json, global: true, ignore_overload_multipliers: overload_multipliers }
    assert_response :success
    assert_equal @planning.routes.size, JSON.parse(response.body)['routes'].size
  end

  test 'should not optimize when an optimization job is already running' do
    customers(:customer_one).update(job_optimizer: delayed_jobs(:job_optimizer))

    get :optimize, params: { planning_id: @planning, format: :json, global: true }
    assert_valid response
    assert_response 422
  end

  test 'should duplicate' do
    assert_difference('Planning.count') do
      patch :duplicate, params: { planning_id: @planning }
    end

    assert_redirected_to edit_planning_path(assigns(:planning))
  end

  test 'should duplicate with error' do
    begin
      orig_validate_during_duplication = Mapotempo::Application.config.validate_during_duplication
      Mapotempo::Application.config.validate_during_duplication = false

      assert_difference('Planning.count') do
        @planning.routes[1].stops[0].index = 666
        @planning.routes[1].stops[0].save!

        patch :duplicate, params: { planning_id: @planning }
      end

      assert_redirected_to edit_planning_path(assigns(:planning))
    ensure
      Mapotempo::Application.config.validate_during_duplication = orig_validate_during_duplication
    end
  end

  test 'should automatic insert one stop' do
    patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }
    assert_response :success
    assert_equal 2, assigns(:routes).length
    routes = JSON.parse(response.body)['routes']
    assert_equal 2, routes.size
    assert_equal [], routes.first['stops']
  end

  test 'should not automatic insert with bad id' do
    patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [1234] }
    assert_valid response
    assert_response 422
  end

  test 'should automatic insert all unaffected stops' do
    assert @planning.routes.detect{|route| !route.vehicle_usage }.stops.any?
    patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [] }
    assert_response :success
    assert @planning.routes.detect{|route| !route.vehicle_usage }.stops.reload.none?
    @planning.routes.select(&:vehicle_usage).each{ |vu|
      assert_not vu.outdated
    }
  end

  test 'should automatic insert twice' do
    patch :automatic_insert, params: { id: @planning.id, format: :json }
    assert_response :success
    patch :automatic_insert, params: { id: @planning.id, format: :json }
    assert_valid response
    assert_response 422
  end

  test 'should automatic insert with skills' do
    skill = Tag.first
    route_with_skill = @planning.routes.select(&:vehicle_usage).last
    route_with_skill.vehicle_usage.update!(tags: [skill])
    unaffected_stop = stops(:stop_unaffected)
    unaffected_stop.visit.update!(tags: [skill])
    assert_nil unaffected_stop.route.vehicle_usage?

    patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [unaffected_stop.id] }
    assert_response :success
    assert_equal unaffected_stop.reload.route, route_with_skill
  end

  test 'should not automatic insert without correct skills' do
    Vehicle.all.each{ |v| v.update tags: [] }
    skill = Tag.first
    route_with_skill = @planning.routes.select(&:vehicle_usage).last
    route_with_skill.vehicle_usage.update!(tags: [skill])
    route_with_skill.update!(locked: true)
    unaffected_stop = stops(:stop_unaffected)
    unaffected_stop.visit.update!(tags: [skill])
    assert_nil unaffected_stop.route.vehicle_usage?

    patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [unaffected_stop.id] }
    assert_response 422
  end

  test 'should not automatic insert with none available routes' do
    @planning.routes.select(&:vehicle_usage_id).each{ |r| r.update locked: true }

    patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }
    assert_valid response
    assert_response 422
  end

  test 'should not automatic insert with error' do
    ApplicationController.stub_any_instance(:server_error, lambda { |*a| raise }) do
      Route.stub_any_instance(:compute, lambda { |*a| raise }) do
        assert_no_difference('Stop.count') do
          assert_raise do
            patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }
            assert_valid response
            assert_response 422
          end
        end
      end
    end
  end

  test 'should update active' do
    without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_one_one).id } do
      patch :active, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, active: :none }
      assert_response :success, response.body
      assert_equal 1, JSON.parse(response.body)['routes'].size
    end
  end

  test 'should reverse route stops' do
    without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_one_one).id } do
      patch :reverse_order, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id }
      assert_response :success, response.body
      assert_equal 1, JSON.parse(response.body)['routes'].size
    end
  end

  test 'should update active while automatic insert is in progress' do
    route = routes(:route_one_one) # routes is another function in stub_any_instance
    stop = stops(:stop_one_one)
    begin
      @planning.routes.each{ |r| r.update(locked: true) if r.vehicle_usage_id && r.id != routes(:route_one_one).id }
      assert_no_difference('Stop.count') do
        # Simulate update active while stop is added in route
        Planning.stub_any_instance(:automatic_insert, lambda { |*a|
          new_connection = Planning.connection_pool.checkout
          new_connection.execute("UPDATE stops SET active=false WHERE id='#{stop.id}'")
          new_connection.execute("UPDATE routes SET outdated=true WHERE id='#{route.id}'")
          send('__minitest_any_instance_stub__automatic_insert', *a)
        }) do

          patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }

          # Needs new connection to be outside transaction
          ActiveRecord::Base.establish_connection(ActiveRecord::Base.connection_config)
        end
      end

      assert !stop.reload.active
      assert_nil stops(:stop_unaffected).reload.route.vehicle_usage_id
    ensure
      new_connection = Planning.connection_pool.checkout
      new_connection.execute("UPDATE stops SET active=true WHERE id='#{stop.id}'")
      new_connection.execute("UPDATE routes SET outdated=false WHERE id='#{route.id}'")
    end
  end

  test 'should use limitation' do
    customer = @planning.customer
    customer.plannings.delete_all
    customer.max_plannings = 1
    customer.save!

    assert_difference('Planning.count', 1) do
      post :create, params: { planning: {
        name: 'new dest',
        vehicle_usage_set_id: @planning.vehicle_usage_set_id
      } }
      assert_response :redirect
    end

    assert_difference('Planning.count', 0) do
      assert_difference('Route.count', 0) do
        post :create, params: { planning: {
          name: 'new 2',
          vehicle_usage_set_id: @planning.vehicle_usage_set_id
        } }
      end
    end
  end

  test 'should not switch on unprocessable entity' do
    @planning.routes.each(&:compute!) # To get correct colors for linestrings

    without_loading Stop, if: -> (obj) { obj.route_id != @planning.routes[1].id && obj.route_id != @planning.routes[2].id } do
      Planning.stub_any_instance(:switch, lambda { |*a| raise ActiveRecord::RecordInvalid.new(self) }) do
        patch :switch, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, vehicle_usage_id: vehicle_usages(:vehicle_usage_one_three).id }
        assert_response :unprocessable_entity
      end

      Planning.stub_any_instance(:switch, lambda { |*a| nil }) do
        patch :switch, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, vehicle_usage_id: vehicle_usages(:vehicle_usage_one_three).id }
        assert_response :unprocessable_entity
      end
    end
  end

  test 'should not automatic insert on unprocessable entity' do
    Planning.stub_any_instance(:automatic_insert, lambda { |*a| raise ActiveRecord::RecordNotFound.new(self) }) do
      patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }
      assert_response :unprocessable_entity
    end

    Planning.stub_any_instance(:automatic_insert, lambda { |*a| nil }) do
      patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }
      assert_response :unprocessable_entity
    end

    Planning.stub_any_instance(:save!, lambda { |*a| raise ActiveRecord::RecordInvalid.new(self) }) do
      patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }
      assert_response :unprocessable_entity
    end

    Planning.stub_any_instance(:save!, lambda { |*a| nil }) do
      patch :automatic_insert, params: { id: @planning.id, format: :json, stop_ids: [stops(:stop_unaffected).id] }
      assert_response :unprocessable_entity
    end
  end

  test 'should not optimize one route on unprocessable entity' do
    # without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_one_one).id } do
      Customer.stub_any_instance(:save!, lambda { |*a| false } ) do
        get :optimize_route, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id }
        assert_valid response
        assert_response :unprocessable_entity
      end

      Planning.stub_any_instance(:optimize, lambda { |*a| raise VRPNoSolutionError } ) do
        get :optimize_route, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id }
        assert_valid response
        assert_response :unprocessable_entity
      end

      Planning.stub_any_instance(:optimize, lambda { |*a| raise ActiveRecord::RecordInvalid.new(self) } ) do
        get :optimize_route, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id }
        assert_valid response
        assert_response :unprocessable_entity
      end
    # end
  end

  test 'should not optimize on unprocessable entity' do
    Planning.stub_any_instance(:save!, lambda { |*a| false } ) do
      get :optimize, params: { planning_id: @planning, format: :json, global: true }
      assert_valid response
      assert_response :unprocessable_entity
    end

    Planning.stub_any_instance(:optimize, lambda { |*a| raise VRPNoSolutionError } ) do
      get :optimize, params: { planning_id: @planning, format: :json, global: true }
      assert_valid response
      assert_response :unprocessable_entity
    end

    Planning.stub_any_instance(:optimize, lambda { |*a| raise ActiveRecord::RecordInvalid.new(self) } ) do
      get :optimize, params: { planning_id: @planning, format: :json, global: true }
      assert_valid response
      assert_response :unprocessable_entity
    end
  end

  test 'should not move on unprocessable entity' do
    without_loading Stop, if: -> (obj) { obj.route_id != @planning.routes[0].id && obj.route_id != @planning.routes[1].id } do
      Planning.stub_any_instance(:compute, lambda { |*a| raise ActiveRecord::RecordInvalid.new(self) }) do
        patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_id: @planning.routes[0].stops[0], index: 1, format: :json }
        assert_response :unprocessable_entity
      end

      Planning.stub_any_instance(:save!, lambda { |*a| false }) do
        patch :move, params: { planning_id: @planning, route_id: @planning.routes[1], stop_id: @planning.routes[0].stops[0], index: 1, format: :json }
        assert_response :unprocessable_entity
      end
    end
  end

  test 'should not refresh on unprocessable entity' do
    Planning.stub_any_instance(:save, lambda { false } ) do
      get :refresh, params: { planning_id: @planning, format: :json }
      assert_response :unprocessable_entity
    end
  end

  test 'should not update stop on unprocessable entity' do
    without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_one_one).id } do
      Route.stub_any_instance(:compute!, lambda { |*a| raise ActiveRecord::RecordInvalid.new(self) }) do
        patch :update_stop, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, stop_id: stops(:stop_one_one).id, stop: { active: false } }
        assert_response :unprocessable_entity
      end

      Route.stub_any_instance(:compute!, lambda { |*a| nil }) do
        patch :update_stop, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, stop_id: stops(:stop_one_one).id, stop: { active: false } }
        assert_response :unprocessable_entity
      end
    end
  end

  test 'should not update active on unprocessable entity' do
    without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_one_one).id } do
      Planning.stub_any_instance(:save, lambda { |*a| false }) do
        patch :active, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, active: :none }
        assert_response :unprocessable_entity
      end
    end
  end

  test 'should not reverse order on unprocessable entity' do
    without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_one_one).id } do
      Planning.stub_any_instance(:save, lambda { |*a| false } ) do
        patch :reverse_order, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id }
        assert_response :unprocessable_entity
      end
    end
  end

  test 'should not apply zonings on unprocessable entity' do
    Planning.stub_any_instance(:save!, lambda { |*a| raise ActiveRecord::RecordInvalid.new(self) } ) do
      patch :apply_zonings, params: { id: @planning, format: :json, planning: { zoning_ids: [zonings(:zoning_one).id] } }
      assert_response :unprocessable_entity
    end

    Planning.stub_any_instance(:save!, lambda { |*a| false } ) do
      patch :apply_zonings, params: { id: @planning, format: :json, planning: { zoning_ids: [zonings(:zoning_one).id] } }
      assert_response :unprocessable_entity
    end
  end

  test 'should not compute because of router exception' do
    ApplicationController.stub_any_instance(:server_error, lambda { |*a| raise }) do
      Route.stub_any_instance(:compute!, lambda { |*a| raise }) do
        assert_no_difference('Stop.count') do
          assert_raises(RuntimeError) do
            patch :apply_zonings, params: { id: @planning, format: :json, planning: { zoning_ids: [zonings(:zoning_one).id] } }
            assert_response :unprocessable_entity
          end
        end
      end
    end
  end
end
