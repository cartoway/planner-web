require 'test_helper'

class V01::DestinationsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActionDispatch::TestProcess

  require Rails.root.join("test/lib/devices/tomtom_base")
  include TomtomBase

  def app
    Rails.application
  end

  setup do
    @destination = destinations(:destination_one)
    @customer = customers(:customer_one)
    @tags = tags.select{ |t| t.customer_id == @customer.id }
    clear_jobs
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/destinations#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should return customer''s destinations' do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @destination.customer.destinations.size, JSON.parse(last_response.body).size
  end

  test 'should return customer''s destinations by ids' do
    get api(nil, 'ids' => @destination.id)
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
    assert_equal @destination.id, JSON.parse(last_response.body)[0]['id']
  end

  test 'should return a destination' do
    get api(@destination.id)
    assert last_response.ok?, last_response.body
    assert_equal @destination.name, JSON.parse(last_response.body)['name']
  end

  test 'should create' do
    assert_difference('Destination.count', 1) do
      assert_difference('Stop.count', 0) do
        @destination.name = 'new dest'
        post api(), @destination.attributes.update({ref: 'foo', tag_ids: @tags.map(&:id)})
        assert last_response.created?, last_response.body
        assert_equal @destination.name, JSON.parse(last_response.body)['name']
      end
    end
  end

  test 'should not create due to ref' do
    assert_difference('Destination.count', 0) do
      assert_difference('Stop.count', 0) do
        post api(), @destination.attributes
        refute last_response.created?, last_response.body
        assert_equal 400, last_response.status, last_response.body
        assert_match "Référence est déjà utilisé(e)", JSON.parse(last_response.body)['message']
      end
    end
  end

  test 'should create with visits' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 2) do
        assert_difference('Stop.count', 4) do
          @destination.name = 'new dest'
          post api(), nil, input: @destination.attributes.update({ref: 'foo', tag_ids: @tags.map(&:id)}).merge(visits: [{
            ref: 'v1',
            quantity1_1: 1,
            time_window_start_1: '08:00',
            time_window_end_1: '12:00',
            time_window_start_2: '13:00',
            time_window_end_2: '14:00',
            duration: nil,
            route: '1',
            active: '1'
          },
          {
            quantity1_1: 2,
            ref: 'v2',
            time_window_start_1: '14:00',
            time_window_end_1: '18:00',
            time_window_start_2: '20:00',
            time_window_end_2: '21:00',
            duration: nil,
            route: '1',
            active: '1'
          }]).to_json, CONTENT_TYPE: 'application/json'

          assert last_response.created?, last_response.body
          assert_equal @destination.name, JSON.parse(last_response.body)['name']
          assert_equal "v1", JSON.parse(last_response.body)['visits'][0]['ref']
        end
      end
    end
  end

  test 'should create with geocode error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      assert_difference('Destination.count', 1) do
        assert_difference('Stop.count', 0) do
          @destination.name = 'new dest'
          post api(), @destination.attributes.update({ref: 'foo', tag_ids: @tags.map(&:id)})
          assert last_response.created?, last_response.body
          assert_equal @destination.name, JSON.parse(last_response.body)['name']
        end
      end
    end
  end

  test 'should create with none tag' do
    ['', nil, []].each.with_index do |tags, index|
      assert_difference('Destination.count', 1) do
        @destination.name = 'new dest'
        post api(), @destination.attributes.update({ref: "foo#{index}", tag_ids: tags})
        assert last_response.created?, last_response.body
      end
    end
  end

  test 'should create bulk from csv' do
    assert_difference('Destination.count', 1) do
      assert_difference('Planning.count', 1) do
        file = fixture_file_upload('test/fixtures/files/import_destinations_one.csv', 'text/csv')
        put api(), replace: false, file: file
        assert last_response.ok?, last_response.body
        assert_equal 1, JSON.parse(last_response.body).size

        get api()
        assert_equal 1, JSON.parse(last_response.body)[0]['visits'][0]['tag_ids'].size
      end
    end
  end

  test 'should create bulk from json' do
    assert_difference('Destination.count', 1) do
      assert_difference('Planning.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 2 +
          2 + @customer.vehicle_usage_sets[1].vehicle_usages.select{ |v| v.default_rest_duration }.size) do
          put api(), nil, input: {
            planning: {
              name: 'Hey',
              ref: 'Hop',
              date: '2123-10-10',
              vehicle_usage_set_id: @customer.vehicle_usage_sets[1].id,
              zoning_ids: [zonings(:zoning_one).id]
            },
            destinations: [{
              name: 'Nouveau client',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z',
              tags: ['tag1', 'tag2'],
              geocoding_accuracy: nil,
              foo: 'bar',
              visits: [{
                ref: 'v1',
                quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, delivery: 1}],
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                time_window_start_2: '14:00',
                time_window_end_2: '18:00',
                duration: nil,
                route: 'useless_because_of_zoning_ids',
                active: '1'
              },
              {
                ref: 'v2',
                quantity1_1: 2,
                time_window_start_1: '14:00',
                time_window_end_1: '18:00',
                time_window_start_2: '20:00',
                time_window_end_2: '21:00',
                priority: 0,
                duration: nil,
                route: 'useless_because_of_zoning_ids',
                active: '1'
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          get api()
          assert_equal 2, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['tag_ids'].size

          # zoning sets stops out_of_route
          planning = Planning.last
          visits = planning.routes.find{ |r| !r.vehicle_usage }.stops.map(&:visit)
          assert_equal ['v1', 'v2'], visits.map(&:ref)
          assert_equal [1, 2], visits.flat_map{ |v| v.deliveries.values }
          assert_nil visits.first.priority
          assert_nil visits.second.priority

          route = Route.last
          assert_equal [route.id], JSON.parse('[' + route.geojson_tracks.join(',') + ']').map{ |t| t['properties']['route_id'] }.uniq
          assert_equal [route.id], JSON.parse('[' + route.geojson_points.join(',') + ']').map{ |t| t['properties']['route_id'] }.uniq

          get '/api/0.1/plannings/ref:Hop.json?api_key=testkey1'
          planning = JSON.parse(last_response.body)
          assert_equal 'Hey', planning['name']
          assert_equal 'Hop', planning['ref']
          assert_equal @customer.vehicle_usage_sets[1].id, planning['vehicle_usage_set_id']
          assert planning['zoning_ids'].size > 0
        end
      end
    end
  end

  test 'should create bulk from json with store destination' do
    @customer.update(enable_store_stops: true)
    orig_locale = I18n.locale
    I18n.locale = :en

    assert_difference('Store.count', 1) do
      assert_difference('Destination.count', 0) do
        assert_difference('Planning.count', 0) do
          assert_difference('Stop.count', 1) do
            put api(), nil, input: {
              planning: {
                ref: 'r1',
              },
              destinations: [{
                vehicle: '001',
                route: 'route_one',
                name: 'New store',
                ref: 'store_ref',
                street: '123 Store Street',
                postalcode: '12345',
                city: 'Store City',
                state: 'Store State',
                lat: 43.5710885456786,
                lng: 3.89636993408203,
                stop_type: 'store'
              }]
            }.to_json, CONTENT_TYPE: 'application/json'
            assert last_response.ok?, last_response.body

            get api()

            # zoning sets stops out_of_route
            planning = plannings(:planning_one)
            stops = planning.routes.find{ |r| r.ref == 'route_one' }.stops
            stop = stops.first
            assert_equal 'StopStore', stop.type
            assert_equal 'store_ref', stop.store.ref
          end
        end
      end
    end
  ensure
    I18n.locale = orig_locale
  end

  test 'should create bulk from json with empty strings for coords' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 1) do
          put api(), nil, input: {
            destinations: [{
              name: 'Nouveau client',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: "",
              lng: "",
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z',
              tags: ['tag1', 'tag2', 999],
              geocoding_accuracy: nil,
              foo: 'bar',
              visits: [{
                ref: 'v1',
                quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, delivery: 1}],
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                time_window_start_2: '14:00',
                time_window_end_2: '18:00',
                duration: nil
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect
        end
      end
    end
  end

  test 'should create bulk from json with string tags' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 1) do
          put api(), nil, input: {
            destinations: [{
              name: 'Nouveau client',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z',
              tags: 'tag1,tag2,tag3',
              geocoding_accuracy: nil,
              foo: 'bar',
              visits: [{
                ref: 'v1',
                quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, pickup: 1}],
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                time_window_start_2: '14:00',
                time_window_end_2: '18:00',
                duration: nil
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          get api()
          assert_equal 3, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['tag_ids'].size
        end
      end
    end
  end

  test 'should create bulk from json with quantity label' do
    deliverable = deliverable_units(:deliverable_unit_one_one)
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        put api(), nil, input: {
          destinations: [{
            name: 'Nouveau client',
            street: nil,
            postalcode: nil,
            city: 'Tule',
            state: 'Limousin',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            detail: nil,
            comment: nil,
            phone_number: nil,
            ref: 'z',
            geocoding_accuracy: nil,
            foo: 'bar',
            visits: [{
              ref: 'v1',
              quantities: [{deliverable_unit_label: deliverable.label, delivery: 1}],
              time_window_start_1: '08:00',
              time_window_end_1: '12:00',
              time_window_start_2: '14:00',
              time_window_end_2: '18:00',
              duration: nil
            }]
          }]
        }.to_json, CONTENT_TYPE: 'application/json'
        assert last_response.ok?, last_response.body
        assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

        get api()
        assert_equal deliverable.id, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['visits'][0]['quantities'][0]['deliverable_unit_id']
        assert_equal 1, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['visits'][0]['quantities'][0]['delivery']
      end
    end
  end

  test 'should create bulk from json with time exceeding one day' do
    assert_difference('Destination.count', 1) do
      assert_difference('Planning.count', 1) do
        put api(), nil, input: {
          planning: {
            name: 'Hey',
            ref: 'Hop',
            date: '2017-10-10',
            vehicle_usage_set_id: @customer.vehicle_usage_sets[1].id,
            zoning_ids: [zonings(:zoning_one).id]
          },
          destinations: [{
            name: 'Nouveau client',
            street: nil,
            postalcode: nil,
            city: 'Tule',
            state: 'Limousin',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            detail: nil,
            comment: nil,
            phone_number: nil,
            ref: 'z',
            tags: ['tag1', 'tag2'],
            geocoding_accuracy: nil,
            foo: 'bar',
            visits: [{
              ref: 'v1',
              quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, delivery: 1}],
              time_window_start_1: '20:00',
              time_window_end_1: '32:00',
              time_window_start_2: '38:00',
              time_window_end_2: '44:00',
              duration: nil,
              route: 'useless_because_of_zoning_ids',
              active: '1'
            },
            {
              ref: 'v2',
              quantity1_1: 2,
              time_window_start_1: '12:00',
              time_window_end_1: '18:00',
              time_window_start_2: '32:00',
              time_window_end_2: '36:00',
              priority: -4,
              duration: nil,
              route: 'useless_because_of_zoning_ids',
              active: '1'
            }]
          }]
        }.to_json, CONTENT_TYPE: 'application/json'
        assert last_response.ok?, last_response.body

        visits = JSON.parse(last_response.body)[0]['visits']

        assert_equal '20:00:00', visits[0]['time_window_start_1']
        assert_equal '32:00:00', visits[0]['time_window_end_1']
        assert_equal '38:00:00', visits[0]['time_window_start_2']
        assert_equal '44:00:00', visits[0]['time_window_end_2']

        assert_equal '12:00:00', visits[1]['time_window_start_1']
        assert_equal '18:00:00', visits[1]['time_window_end_1']
        assert_equal '32:00:00', visits[1]['time_window_start_2']
        assert_equal '36:00:00', visits[1]['time_window_end_2']
      end
    end
  end

  test 'should create bulk from json with ref vehicle' do
    assert_difference('Destination.count', 1) do
      assert_difference('Planning.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 2 +
          2 + vehicle_usage_sets(:vehicle_usage_set_one).vehicle_usages.select{ |v| v.default_rest_duration }.size) do
          put api(), nil, input: {
            planning: {
              name: 'Hey',
              ref: 'Hop',
              vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id
            },
            destinations: [{
              name: 'Nouveau client',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z',
              tags: ['tag1', 'tag2'],
              geocoding_accuracy: nil,
              foo: 'bar',
              visits: [{
                ref: 'v1',
                quantity1_1: 1,
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                time_window_start_2: '14:00',
                time_window_end_2: '18:00',
                duration: nil,
                route: '1',
                ref_vehicle: '003',
                active: true
              },
              {
                ref: 'v2',
                quantity1_1: 2,
                time_window_start_1: '14:00',
                time_window_end_1: '18:00',
                time_window_start_2: '20:00',
                time_window_end_2: '21:00',
                duration: nil,
                route: '1',
                ref_vehicle: '003',
                active: true
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          get api()
          assert_equal 2, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['tag_ids'].size

          planning = Planning.last
          assert planning.routes.find{ |r| r.vehicle_usage.try(&:vehicle).try(&:ref) == '003' }.stops.select{ |s| s.is_a? StopVisit }.map(&:visit).map(&:ref) == ['v1', 'v2']
        end
      end
    end
  end

  test 'should save route after import' do
    put api(), nil, input: {
      planning: {
        ref: 'r1',
        name: 'Hey',
        vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id
      },
      replace: true,
      destinations: [{
        name: 'Nouveau client',
        street: nil,
        postalcode: nil,
        city: 'Tule',
        state: 'Limousin',
        lat: 43.5710885456786,
        lng: 3.89636993408203,
        detail: nil,
        comment: nil,
        phone_number: nil,
        ref: 'z',
        tags: ['tag1', 'tag2'],
        geocoding_accuracy: nil,
        foo: 'bar',
        visits: [{
          ref: 'v1',
          quantity1_1: 1,
          time_window_start_1: '08:00',
          time_window_end_1: '12:00',
          time_window_start_2: '14:00',
          time_window_end_2: '18:00',
          duration: nil,
          route: '1',
          ref_vehicle: '003',
          active: true
        },
        {
          ref: 'v2',
          quantity1_1: 2,
          time_window_start_1: '14:00',
          time_window_end_1: '18:00',
          time_window_start_2: '20:00',
          time_window_end_2: '21:00',
          duration: nil,
          route: '1',
          ref_vehicle: '003',
          active: true
        }]
      }]
    }.to_json, CONTENT_TYPE: 'application/json'
    assert last_response.ok?, last_response.body

    planning = Planning.last
    assert_not_nil planning.routes.load.last.stop_drive_time
  end

  test 'should create bulk from json with tag_id' do
    assert_difference('Destination.count', 1) do
      assert_difference('Planning.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 2 +
          2 + @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.active && v.default_rest_duration }.size) do
          put api(), {destinations: [{
            name: 'Nouveau client',
            street: nil,
            postalcode: nil,
            city: 'Tule',
            state: 'Limousin',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            detail: nil,
            comment: nil,
            phone_number: nil,
            ref: 'z',
            tag_ids: [tags(:tag_one).id, tags(:tag_two).id],
            geocoding_accuracy: nil,
            foo: 'bar',
            visits: [{
              ref: 'v1',
              quantity1_1: nil,
              time_window_start_1: nil,
              time_window_end_1: nil,
              time_window_start_2: nil,
              time_window_end_2: nil,
              duration: nil,
              route: '1',
              active: '1'
            },{
              ref: 'v2',
              quantity1_1: nil,
              time_window_start_1: nil,
              time_window_end_1: nil,
              time_window_start_2: nil,
              time_window_end_2: nil,
              duration: nil,
              route: '1',
              active: '1'
            }]
          }]}.to_json,
          'CONTENT_TYPE' => 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          get api()
          assert_equal 2, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['tag_ids'].size
        end
      end
    end
  end

  test 'should create bulk from json with visit tag_id' do
    assert_difference('Destination.count', 1) do
      assert_difference('Planning.count', 1) do
        put api(), {destinations: [{
          name: 'Nouveau client',
          street: nil,
          postalcode: nil,
          city: 'Tule',
          state: 'Limousin',
          lat: 43.5710885456786,
          lng: 3.89636993408203,
          detail: nil,
          comment: nil,
          phone_number: nil,
          ref: 'z',
          geocoding_accuracy: nil,
          foo: 'bar',
          visits: [{
            ref: 'v1',
            quantity1_1: nil,
            time_window_start_1: nil,
            time_window_end_1: nil,
            time_window_start_2: nil,
            time_window_end_2: nil,
            duration: nil,
            route: '1',
            active: '1',
            tag_ids: [tags(:tag_one).id, tags(:tag_two).id],
          },{
            ref: 'v2',
            quantity1_1: nil,
            time_window_start_1: nil,
            time_window_end_1: nil,
            time_window_start_2: nil,
            time_window_end_2: nil,
            duration: nil,
            route: '1',
            active: '1'
          }]
        }]}.to_json,
        'CONTENT_TYPE' => 'application/json'
        assert last_response.ok?, last_response.body
        assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

        get api()
        assert_equal 2, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['visits'].find{ |v| v['ref'] == 'v1' }['tag_ids'].size
        assert_equal 0, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['visits'].find{ |v| v['ref'] == 'v2' }['tag_ids'].size
      end
    end
  end

  test 'should create bulk from json with visit ref' do
    assert_difference('Destination.count', 1) do
      assert_difference('Planning.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 2 +
          2 + @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.active && v.default_rest_duration }.size) do
          put api(), nil, input: {destinations: [{
            name: 'Nouveau client',
            street: nil,
            postalcode: nil,
            city: 'Tule',
            state: 'Limousin',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            detail: nil,
            comment: nil,
            phone_number: nil,
            ref: 'z',
            tags: ['tag1', 'tag2'],
            geocoding_accuracy: nil,
            foo: 'bar',
            visits: [{
              #to keep the same behavior between destinations refs and visits refs. visit can't be validated if no visit_ref have been settled.
              ref: 'v1',
              quantity1_1: 1,
              time_window_start_1: '08:00',
              time_window_end_1: '12:00',
              time_window_start_2: '13:00',
              time_window_end_2: '14:00',
              duration: nil,
              route: '1',
              active: '1'
            },
            {
              quantity1_1: 2,
              ref: 'v2',
              time_window_start_1: '14:00',
              time_window_end_1: '18:00',
              time_window_start_2: '20:00',
              time_window_end_2: '21:00',
              duration: nil,
              route: '1',
              active: '1'
            }]
          }]}.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          get api()
          assert_equal 2, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['tag_ids'].size
        end
      end
    end
  end

  test 'should create bulk from json without visit' do
    assert_difference('Destination.count', 1) do
      assert_no_difference('Visit.count') do
        assert_no_difference('Planning.count') do
          put api(), nil, input: {destinations: [{
            name: 'Nouveau client',
            street: nil,
            postalcode: nil,
            city: 'Tule',
            state: 'Limousin',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            detail: nil,
            comment: nil,
            phone_number: nil,
            ref: 'z',
            tags: ['tag1', 'tag2'],
            geocoding_accuracy: nil,
            foo: 'bar',
            visits: []
          }]}.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          get api()
          assert_equal 2, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['tag_ids'].size
        end
      end
    end
  end

  test 'should update bulk from json without visit' do
    assert_no_difference('Destination.count') do
      assert_no_difference('Visit.count') do
        assert_no_difference('StopVisit.count') do
          assert_no_difference('Planning.count') do
            put api, {destinations: [ref: @customer.destinations.first.ref]}.to_json, 'CONTENT_TYPE' => 'application/json'
            assert [true], @customer.plannings.flat_map(&:routes).map{ |r|
              r.stops.collect(&:index).sum == (r.stops.length * (r.stops.length + 1)) / 2
            }.uniq
          end
        end
      end
    end
  end

  test 'should create bulk from json without empty route' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert_difference('Planning.count', 1) do
          put api(), nil, input: {
            planning: {
              name: 'Hey'
            },
            destinations: [{
              name: 'Nouveau client',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z',
              tags: ['tag1', 'tag2'],
              geocoding_accuracy: nil,
              foo: 'bar',
              visits: [{
                quantity1_1: 2,
                ref: 'v1',
                duration: nil,
                route: '', # Should be imported in unplanned
                active: '1'
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          get api()
          assert_equal 2, JSON.parse(last_response.body).find{ |destination| destination['name'] == 'Nouveau client' }['tag_ids'].size
        end
      end
    end
  end

  test 'should not create bulk from json containing too many routes' do
    assert_no_difference('Destination.count') do
      assert_no_difference('Visit.count') do
        assert_no_difference('Stop.count') do
          put api(), nil, input: {destinations: [{
            name: 'N1',
            city: 'Tule',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            visits: [{
              ref: 'v1',
              route: '1',
              active: '1'
            },
            {
              ref: 'v2',
              route: '2',
              active: '1'
            }]
          },
          {
            name: 'N2',
            city: 'Brive',
            lat: 45.158556,
            lng: 1.532553,
            visits: [{
              ref: 'v3',
              route: '3',
              active: '1'
            },
            {
              ref: 'v4',
              route: '4',
              active: '1'
            }]
          }]}.to_json, CONTENT_TYPE: 'application/json'
          assert !last_response.ok?, last_response.body
          assert_not_nil JSON.parse(last_response.body)['error'], 'Bad response: ' + last_response.body.inspect
        end
      end
    end
  end

  test 'should throw error when trying to import multi refs' do
    assert_no_difference('Destination.count', 1) do
      assert_no_difference('Planning.count', 1) do
        assert_no_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 2 +
          2 + @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.active && v.default_rest_duration }.size) do
          put api(), {destinations: [{
            name: 'Nouveau client',
            street: nil,
            postalcode: nil,
            city: 'Tule',
            state: 'Limousin',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            detail: nil,
            comment: nil,
            phone_number: nil,
            ref: 'z',
            tag_ids: [tags(:tag_one).id, tags(:tag_two).id],
            geocoding_accuracy: nil,
            foo: 'bar',
            visits: [{
              ref: 'v1',
              quantity1_1: nil,
              time_window_start_1: nil,
              time_window_end_1: nil,
              time_window_start_2: nil,
              time_window_end_2: nil,
              duration: nil,
              route: '1',
              active: '1'
            },{
              ref: 'v1',
              quantity1_1: nil,
              time_window_start_1: nil,
              time_window_end_1: nil,
              time_window_start_2: nil,
              time_window_end_2: nil,
              duration: nil,
              route: '1',
              active: '1'
            }]
          }]}.to_json,
          'CONTENT_TYPE' => 'application/json'
          assert_not last_response.ok?, last_response.body
          error_message = I18n.t('destinations.import_file.refs_duplicate', refs: "z | v1")
          assert_equal error_message, JSON.parse(last_response.body)["error"][0].scan(error_message)[0]
        end
      end
    end
  end

  test 'should create bulk from tomtom' do
    @customer = add_tomtom_credentials customers(:customer_one)

    with_stubs [:address_service_wsdl, :show_address_report] do
      assert_difference('Destination.count', 1) do
        put api(), replace: false, remote: :tomtom
        assert_equal 202, last_response.status, 'Bad response: ' + last_response.body
      end
    end
  end

  test 'should update a destination with deprecated quantity field' do
    [
      tags(:tag_one).id.to_s + ',' + tags(:tag_two).id.to_s,
      [tags(:tag_one).id, tags(:tag_two).id],
      '',
      nil,
      []
    ].each do |tags|
      @destination.name = 'new name'
      put api(@destination.id), nil, input: @destination.attributes.merge(tag_ids: tags, visits: [ref: 'api', quantity: 5]).to_json, CONTENT_TYPE: 'application/json'
      assert last_response.ok?, last_response.body
      destination = JSON.parse(last_response.body)
      assert_equal @destination.name, destination['name']
      assert_equal 5, destination['visits'].find{ |v| v['ref'] == 'api' }['quantities'][0]['delivery']

      get api(@destination.id)
      assert last_response.ok?, last_response.body
      assert_equal @destination.name, JSON.parse(last_response.body)['name']
    end
  end

  test 'should catch excpetions when updating destination with wrong arguments' do
    put api, {
      destinations: [
        @destination.attributes.merge(visits: [{quantities: [{label: 'kg', delivery: 10}]}])
      ]
    }.to_json, 'CONTENT_TYPE' => 'application/json'
    body = JSON.parse(last_response.body)

    assert_equal 400, last_response.status
    assert_equal 'destinations[0][visits][0][quantities][0][deliverable_unit_id], destinations[0][visits][0][quantities][0][deliverable_unit_label] are missing, at least one parameter must be provided', body['message']
  end

  test 'should destroy a destination' do
    routes = @destination.visits.flat_map{ |v| v.stop_visits.map(&:route) }
    assert_difference('Destination.count', -1) do
      delete api(@destination.id)
      assert_equal 204, last_response.status, last_response.body
      routes.each do |route|
        assert_equal (route.stops.length * (route.stops.length + 1)) / 2, route.stops.collect(&:index).sum
      end
    end
  end

  test 'should destroy multiple destinations' do
    assert_difference('Destination.count', -3) do
      # destination_four is from another customer
      delete api + "&ids=#{destinations(:destination_one).id},#{destinations(:destination_two).id},#{destinations(:destination_three).id},#{destinations(:destination_four).id}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy all destinations without params' do
    assert_difference('Destination.count', -4) do
      delete api
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy all destinations when all ids/ref in params' do
    assert_difference('Destination.count', -4) do
      ids = @customer.destinations[0..@customer.destinations.count/2-1].map(&:id)
      refs = @customer.destinations[@customer.destinations.count/2..@customer.destinations.count].map(&:ref)
      delete api + "&ids=#{ids.join(',')},ref:#{refs.join(',ref:')}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should geocode' do
    patch api('geocode'), format: :json, destination: { city: @destination.city, name: @destination.name, postalcode: @destination.postalcode, street: @destination.street, state: @destination.state }
    assert last_response.ok?, last_response.body
  end

  test 'should geocode with error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      patch api('geocode'), format: :json, destination: { city: @destination.city, name: @destination.name, postalcode: @destination.postalcode, street: @destination.street, state: @destination.state }
      assert last_response.ok?, last_response.body
    end
  end

  test 'should geocode complete' do
    patch api('geocode_complete'), format: :json, id: @destination.id, destination: { city: 'Montpellier', street: 'Rue de la Chaînerais' }
    assert last_response.ok?, last_response.body
    assert_equal 10, JSON.parse(last_response.body).length
  end

  test 'Update Destination' do
    visit = visits :visit_one
    destination_params = @destination.attributes.slice(*(@destination.attributes.keys - ['id']))
    visit_attributes = visit.api_attributes.slice(*(visit.api_attributes.keys - ['created_at', 'updated_at']))
    destination_params.merge! 'visits_attributes' => [visit_attributes]
    put api(@destination.id), destination_params
    assert last_response.ok?, last_response.body
  end

  # Disabled as deprecated
  # test 'Update Destination with Deprecated Params' do
  #   visit = visits :visit_one
  #   destination_params = @destination.attributes.slice *@destination.attributes.keys - ['id']
  #   visit_attributes = visit.attributes.slice *visit.attributes.keys - ['created_at', 'updated_at']

  #   open_time = 15.hours.to_i
  #   visit_attributes.delete 'time_window_start_1'
  #   visit_attributes['open'] = open_time

  #   close_time = 17.hours.to_i
  #   visit_attributes.delete 'time_window_end_1'
  #   visit_attributes['close'] = close_time

  #   destination_params.merge! 'visits_attributes' => [ visit_attributes ]
  #   put api(@destination.id), destination_params
  #   assert last_response.ok?, last_response.body

  #   assert_equal open_time, visit.reload.time_window_start_1
  #   assert_equal close_time, visit.reload.time_window_end_1
  # end

  test 'should use limitation' do
    customer = @destination.customer
    customer.destinations.delete_all
    customer.max_destinations = 1
    customer.save!

    assert_difference('Destination.count', 1) do
      post api(), @destination.attributes
      assert last_response.created?, last_response.body
    end

    assert_difference('Destination.count', 0) do
      post api(), @destination.attributes.merge(ref: 'foo')
      assert last_response.forbidden?, last_response.body
      assert_equal 'dépassement du nombre maximal de destinations', JSON.parse(last_response.body)['message']
    end
  end

  test 'should reverse geocoding' do
    Planner::Application.config.geocoder.expects(:reverse).with(44.821934, -0.6211603).returns("{\"type\":\"FeatureCollection\",\"geocoding\":{\"version\":\"draft#namespace#score\",\"licence\":\"ODbL\",\"attribution\":\"BANO\"},\"features\":[{\"properties\":{\"geocoding\":{\"geocoder_version\":\"Wrapper:1.0.0 - addok:1.1.0-rc1\",\"score\":0.9999997217790441,\"type\":\"house\",\"label\":\"35 Rue de Marseille 33700 Mérignac\",\"name\":\"35 Rue de Marseille\",\"housenumber\":\"35\",\"street\":\"Rue de Marseille\",\"postcode\":\"33700\",\"city\":\"Mérignac\",\"country\":\"France\",\"id\":\"33281_1980_addff9\"}},\"type\":\"Feature\",\"geometry\":{\"coordinates\":[-0.620826,44.821944],\"type\":\"Point\"}}]}")

    patch api('reverse', {lat: 44.821934, lng: -0.6211603})

    assert last_response.ok?, last_response.body
    assert last_response.body['success']
    refute_empty last_response.body['result']
  end

  test 'should import existing store with ref' do
    @customer.update(enable_store_stops: true)
    orig_locale = I18n.locale
    I18n.locale = :en
    # Get existing store from fixtures
    existing_store = stores(:store_one)

    assert_difference('Store.count', 0) do
      assert_difference('Stop.count', 1) do
        put api(), nil, input: {
          planning: {
            ref: 'r1',
          },
          destinations: [{
            route: 'route_one',
            vehicle: '001',
            ref: existing_store.ref,
            stop_type: 'store'
          }]
        }.to_json, CONTENT_TYPE: 'application/json'

        assert last_response.ok?, last_response.body

        planning = plannings(:planning_one)
        stops = planning.routes.find{ |r| r.ref == 'route_one' }.stops
        stop = stops.first
        assert_equal 'StopStore', stop.type
        assert_equal existing_store.ref, stop.store.ref
      end
    end
  ensure
    I18n.locale = orig_locale
  end

  test 'should create bulk from json with stop custom attributes for visit' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 1 + 2) do
          put api(), nil, input: {
            destinations: [{
              name: 'New client with custom attributes',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z_custom',
              tags: ['tag1', 'tag2'],
              geocoding_accuracy: nil,
              visits: [{
                ref: 'custom_custom',
                quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, delivery: 1}],
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                duration: nil,
                route: 'route_one',
                stop_custom_attributes: {
                  'stop_custom_field' => 'custom_value',
                  'stop_priority' => 5,
                  'stop_urgent' => true
                }
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body

          stop = Stop.joins(:visit).where(visits: { ref: 'custom_custom' }).order(created_at: :desc).first
          assert_equal 'custom_value', stop.custom_attributes['stop_custom_field']
          assert_equal 5, stop.custom_attributes['stop_priority']
          assert_equal true, stop.custom_attributes['stop_urgent']

          stop = Stop.joins(:visit).where(visits: { ref: 'custom_custom' }).order(created_at: :desc).last
          assert_empty stop.custom_attributes
        end
      end
    end
  end

  test 'should create bulk from json with stop custom attributes for store' do
    @customer.update(enable_store_stops: true)
    orig_locale = I18n.locale
    I18n.locale = :en

    assert_difference('Store.count', 1) do
      assert_difference('Destination.count', 0) do
        assert_difference('Planning.count', 0) do
          assert_difference('Stop.count', 1) do
            put api(), nil, input: {
              planning: {
                ref: 'r1',
              },
              destinations: [{
                vehicle: '001',
                route: 'route_one',
                name: 'New store with custom attributes',
                ref: 'store_ref_custom',
                street: '123 Store Street',
                postalcode: '12345',
                city: 'Store City',
                state: 'Store State',
                lat: 43.5710885456786,
                lng: 3.89636993408203,
                stop_type: 'store',
                stop_custom_attributes: {
                  'stop_custom_field' => 'store_custom_value',
                  'stop_priority' => 10,
                  'stop_urgent' => false
                }
              }]
            }.to_json, CONTENT_TYPE: 'application/json'
            assert last_response.ok?, last_response.body

            stop = Stop.joins(:store).where(stores: { ref: 'store_ref_custom' }).order(created_at: :desc).first
            assert_not_nil stop, 'Stop should be created'
            assert_equal 'store_custom_value', stop.custom_attributes['stop_custom_field']
            assert_equal 10, stop.custom_attributes['stop_priority']
            assert_equal false, stop.custom_attributes['stop_urgent']
          end
        end
      end
    end
  ensure
    I18n.locale = orig_locale
  end

  test 'should create bulk from json with stop custom attributes and active status' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 1 + 2) do
          put api(), nil, input: {
            destinations: [{
              name: 'New client with custom attributes and active',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z_custom_active',
              tags: ['tag1', 'tag2'],
              geocoding_accuracy: nil,
              visits: [{
                ref: 'v1_custom_active',
                quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, delivery: 1}],
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                duration: nil,
                route: 'route_one',
                active: false,
                stop_custom_attributes: {
                  'stop_custom_field' => 'inactive_value',
                  'stop_priority' => 1
                }
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          stop = Stop.joins(:visit).where(visits: { ref: 'v1_custom_active' }).order(created_at: :desc).first
          assert stop, 'Stop should be created'
          assert_not stop.active, 'Stop should be inactive'
          assert_equal 'inactive_value', stop.custom_attributes['stop_custom_field']
          assert_equal 1, stop.custom_attributes['stop_priority']
        end
      end
    end
  end

  test 'should create bulk from json with empty stop custom attributes' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count',
          @customer.plannings.select{ |p| p.tags_compatible?([tags(:tag_one), tags(:tag_two)]) }.size * 1 + 2) do
          put api(), nil, input: {
            destinations: [{
              name: 'New client with empty custom attributes',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z_custom_empty',
              tags: ['tag1', 'tag2'],
              geocoding_accuracy: nil,
              visits: [{
                ref: 'v1_custom_empty',
                quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, delivery: 1}],
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                duration: nil,
                route: 'route_one',
                stop_custom_attributes: {}
              }]
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          stop = Stop.joins(:visit).where(visits: { ref: 'v1_custom_empty' }).order(created_at: :desc).first
          assert_not_nil stop, 'Stop should be created'
          assert stop.custom_attributes.empty?, 'Custom attributes should be empty'
        end
      end
    end
  end

  test 'should create bulk from json with stop custom attributes without route' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert_difference('Stop.count', 2) do # No stop created because no route
          put api(), nil, input: {
            destinations: [{
              name: 'New client without route',
              street: nil,
              postalcode: nil,
              city: 'Tule',
              state: 'Limousin',
              lat: 43.5710885456786,
              lng: 3.89636993408203,
              detail: nil,
              comment: nil,
              phone_number: nil,
              ref: 'z_without_route',
              tags: ['tag1', 'tag2'],
              geocoding_accuracy: nil,
              visits: [{
                ref: 'v1_without_route',
                quantities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, delivery: 1}],
                time_window_start_1: '08:00',
                time_window_end_1: '12:00',
                duration: nil
              }],
              stop_custom_attributes: {
                'stop_custom_field' => 'value_without_route'
              }
            }]
          }.to_json, CONTENT_TYPE: 'application/json'
          assert last_response.ok?, last_response.body
          assert_equal 1, JSON.parse(last_response.body).size, 'Bad response size: ' + last_response.body.inspect

          stop = Stop.joins(:visit).where(visits: { ref: 'v1_without_route' }).order(created_at: :desc).first
          assert stop
          refute stop.route.vehicle_usage?
        end
      end
    end
  end
end

class V01::DestinationsWithJobTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActionDispatch::TestProcess

  require Rails.root.join("test/lib/devices/tomtom_base")
  include TomtomBase

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
    @destination = destinations(:destination_one)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/destinations#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should not create due to job' do
    assert_difference('Destination.count', 0) do
      assert_difference('Stop.count', 0) do
        post api(), @destination.attributes
        assert_equal 409, last_response.status, last_response.body
      end
    end
  end

  test 'should not update a destination due to job' do
    put api(@destination.id), nil, input: @destination.attributes.to_json
    assert_equal 409, last_response.status
  end

  test 'should not destroy a destination due to job' do
    assert_difference('Destination.count', 0) do
      delete api(@destination.id)
      assert_equal 409, last_response.status, last_response.body
    end
  end

  test 'should import sequential destinations in same planning' do
    Planning.all.each(&:destroy)
    @customer.delete_all_destinations
    @customer.vehicle_usage_sets.each{ |vus| vus.vehicle_usages.each{ |vu| (vu.active = true) && vu.save }}
    @customer.reload

    # Import and create a new planning with one destination
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', 1) do
        put api(), { replace: true }.merge(JSON.parse(File.read('test/fixtures/files/import_destinations_sequential_1.json')))
        assert_equal 200, last_response.status, last_response.body
      end
    end

    @customer.reload
    planning = @customer.plannings.find_by(ref: 'Test-1')
    route = planning.routes.find{ |r| r.vehicle_usage&.vehicle&.ref == '001' }
    assert planning
    assert_equal 2, route.stops.count # 1 + rest

    # Import and add a new destination to the same planning
    assert_difference('Planning.count', 0) do
      assert_difference('Destination.count', 1) do
        put api(), { replace: false }.merge(JSON.parse(File.read('test/fixtures/files/import_destinations_sequential_2.json')))
        assert_equal 200, last_response.status, last_response.body
      end
    end

    @customer.reload
    planning.reload
    route.reload
    assert_equal 3, route.stops.size # 2 + rest

    # The rest is in first position
    assert_equal 'a', route.stops[0].visit.ref
    assert_equal 'b', route.stops[1].visit.ref
  end

  test 'should import sequential destinations in same planning in no route' do
    Planning.all.each(&:destroy)
    @customer.delete_all_destinations
    @customer.vehicle_usage_sets.each{ |vus| vus.vehicle_usages.each{ |vu| (vu.active = true) && vu.save }}
    @customer.reload

    # Import and create a new planning with one destination in the out_route
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', 1) do
        plan_hash = JSON.parse(File.read('test/fixtures/files/import_destinations_sequential_1.json'))
        plan_hash["destinations"].each{ |dest|
          # remove the route field
          dest["visits"].first.delete("route")
        }
        put api(), { replace: true }.merge(plan_hash)
        assert_equal 200, last_response.status, last_response.body
      end
    end

    @customer.reload
    planning = @customer.plannings.find_by(ref: 'Test-1')
    out_route = planning.routes.find{ |r| r.vehicle_usage.nil? }
    assert planning
    assert_equal 1, out_route.stops.count # 1 + rest

    # Import and add a new destination to the same planning in the out_route
    assert_difference('Planning.count', 0) do
      assert_difference('Destination.count', 1) do
        plan_hash = JSON.parse(File.read('test/fixtures/files/import_destinations_sequential_2.json'))
        # remove the route field
        plan_hash["destinations"].each{ |dest|
          dest["visits"].first.delete("route")
        }
        put api(), { replace: false }.merge(plan_hash)
        assert_equal 200, last_response.status, last_response.body
      end
    end

    @customer.reload
    planning.reload
    out_route.reload
    assert_equal 2, out_route.stops.size

    assert_equal 'a', out_route.stops[0].visit.ref
    assert_equal 'b', out_route.stops[1].visit.ref
  end
end
