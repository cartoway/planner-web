require 'test_helper'

require 'rexml/document'
require 'csv'

class RoutesControllerTest < ActionController::TestCase
  include REXML

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @route = routes(:route_one_one)
    sign_in users(:user_one)
  end

  test 'user can only view routes from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @route
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @route

    get :show, params: { id: routes(:route_one_three) }
    assert_response :redirect
  end

  test 'should show route' do
    get :show, params: { id: @route }
    assert_response :success
    assert_valid response
  end

  test 'should show route when start depot is missing' do
    vehicle_usage = @route.vehicle_usage
    vehicle_usage.update!(store_start: nil)

    get :show, params: { id: @route }
    assert_response :success
    assert_valid response
  end

  test 'should show route when start depot is missing and start_with_service is present' do
    vehicle_usage = @route.vehicle_usage
    vehicle_usage.update!(store_start: nil, service_time_start: 15.minutes.to_i)
    @route.route_data.update!(start: 8.hours.to_i)

    get :show, params: { id: @route }
    assert_response :success
    assert_valid response
    assert_includes response.body, '08:15'
  end

  test 'should show route when end depot is missing' do
    vehicle_usage = @route.vehicle_usage
    vehicle_usage.update!(store_stop: nil)

    get :show, params: { id: @route }
    assert_response :success
    assert_valid response
  end

  test 'should show route when end depot is missing and end_without_service is present' do
    vehicle_usage = @route.vehicle_usage
    vehicle_usage.update!(store_stop: nil, service_time_end: 15.minutes.to_i)
    @route.route_data.update!(end: 17.hours.to_i)

    get :show, params: { id: @route }
    assert_response :success
    assert_valid response
    assert_includes response.body, '16:45'
  end

  test 'should show route as csv' do
    get :show, params: { id: @route, type: :csv }
    assert_response :success
  end

  test 'should show route as excel' do
    get :show, params: { id: @route, format: :excel }
    assert_response :success
  end

  test 'should show route as gpx' do
    get :show, params: { id: @route, format: :gpx }
    assert_response :success
    assert Document.new(response.body)
  end

  test 'should show route as kml' do
    get :show, params: { id: @route, format: :kml }
    assert_response :success
    assert Document.new(response.body)
  end

  test 'should show route as kmz' do
    get :show, params: { id: @route, format: :kmz }
    assert_response :success
  end

  test 'should show route as kmz by email' do
    get :show, params: { id: @route, format: :kmz, email: 1 }
    assert_response :success
  end

  test 'should update route' do
    patch :update, params: { id: @route, route: { hidden: @route.hidden, locked: @route.locked, ref: 'ref8' } }
    assert_redirected_to route_path(assigns(:route))
  end

  test 'should update route without loading stops' do
    without_loading Stop do
      patch :update, params: { id: @route, route: { hidden: @route.hidden, locked: @route.locked, ref: 'ref8' } }
      assert_response 302
    end
  end

  test 'should export StopStore duration and destination_duration correctly in csv' do
    # Create a StopStore with a store_reload that has a duration
    store = stores(:store_one)
    store_reload = store.store_reloads.create!(
      ref: 'TEST_RELOAD',
      duration: 25.minutes.to_i # 1500 seconds = 00:25:00
    )

    stop_store = @route.add_store_reload(store_reload, 1)
    stop_store.save!
    @route.reload

    # Export route as CSV
    get :show, params: { id: @route, format: :csv }
    assert_response :success

    # Parse CSV response
    csv_lines = CSV.parse(response.body)
    headers = csv_lines.first

    # Find the duration and destination_duration column indices
    duration_index = headers.index(I18n.t('destinations.import_file.duration'))
    destination_duration_index = headers.index(I18n.t('destinations.import_file.destination_duration'))

    assert_not_nil duration_index, 'duration column should exist'
    assert_not_nil destination_duration_index, 'destination_duration column should exist'

    # Find the row for our StopStore (should have the store_reload ref)
    stop_store_row = csv_lines.find { |row| row[headers.index(I18n.t('destinations.import_file.ref_visit'))] == 'TEST_RELOAD' }
    assert_not_nil stop_store_row, 'StopStore row should exist in CSV export'

    # Verify duration is exported correctly (should be 00:25:00)
    expected_duration = store_reload.duration_time_with_seconds
    assert_equal expected_duration, stop_store_row[duration_index],
                 "duration should be #{expected_duration} but got #{stop_store_row[duration_index]}"

    # Verify destination_duration is nil for StopStore
    assert_nil stop_store_row[destination_duration_index],
               "destination_duration should be nil for StopStore but got #{stop_store_row[destination_duration_index]}"
  end

  # Tests for driver_update action
  test 'should update route status via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)
    original_start_status = route.start_route_data.status
    original_stop_status = route.stop_route_data.status

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        start_route_data_attributes: {
          status: 'completed',
        },
        stop_route_data_attributes: {
          status: 'completed'
        }
      },
      format: :json
    }

    assert_response :success
    assert_equal({ 'success' => true }, JSON.parse(response.body))
    route.reload
    assert_equal 'completed', route.start_route_data.status
    assert_not_equal original_start_status, route.start_route_data.status
    assert_equal 'completed', route.stop_route_data.status
    assert_not_equal original_stop_status, route.stop_route_data.status
  end

  test 'should update route custom_attributes via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        custom_attributes: { 'test_field' => 'test_value' }
      },
      format: :json
    }

    assert_response :success
    assert_equal({ 'success' => true }, JSON.parse(response.body))
    route.reload
    assert_equal 'test_value', route.custom_attributes['test_field']
  end

  test 'should update route status and custom_attributes together via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)

    CustomAttribute.create!(
      customer: vehicle.customer,
      name: 'driver_note',
      object_class: 'route',
      related_field: 'start_route_data',
      object_type: 'string'
    )

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        start_route_data_attributes: {
          status: 'in_progress'
        },
        custom_attributes: { 'start_route_data:driver_note' => 'On route' }
      },
      format: :json
    }

    assert_response :success
    assert_equal({ 'success' => true }, JSON.parse(response.body))
    route.reload
    assert_equal 'in_progress', route.start_route_data.status
    assert_equal 'On route', route.custom_attributes_typed_hash(related_field: :start_route_data)['driver_note']
  end

  test 'should distinguish start_route_data and stop_route_data custom_attributes via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)

    CustomAttribute.create!(
      customer: vehicle.customer,
      name: 'odometer',
      object_class: 'route',
      related_field: 'start_route_data',
      object_type: 'float'
    )
    CustomAttribute.create!(
      customer: vehicle.customer,
      name: 'odometer',
      object_class: 'route',
      related_field: 'stop_route_data',
      object_type: 'float'
    )

    # Update start custom attribute
    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        start_route_data_attributes: { status: 'in_progress' },
        custom_attributes: {
          'start_route_data:odometer' => '100'
        }
      },
      format: :json
    }
    assert_response :success
    route.reload
    assert_equal 100, route.custom_attributes_typed_hash(related_field: :start_route_data)['odometer']
    assert_not route.custom_attributes_has_key?('odometer', related_field: :stop_route_data),
               'stop_route_data odometer should not be set yet'

    # Update stop custom attribute without overwriting start
    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        stop_route_data_attributes: { status: 'atstore' },
        custom_attributes: {
          'stop_route_data:odometer' => '250'
        }
      },
      format: :json
    }
    assert_response :success
    route.reload
    assert_equal 100, route.custom_attributes_typed_hash(related_field: :start_route_data)['odometer']
    assert_equal 250, route.custom_attributes_typed_hash(related_field: :stop_route_data)['odometer']
  end

  test 'should not update route hidden via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)
    original_hidden = route.hidden

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        stop_route_data_attributes: {
          status: 'completed'
        },
        hidden: !original_hidden
      },
      format: :json
    }

    assert_response :success
    route.reload
    assert_equal original_hidden, route.hidden, 'hidden should not be updated via driver_update'
  end

  test 'should not update route locked via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)
    original_locked = route.locked

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        stop_route_data_attributes: {
          status: 'completed'
        },
        locked: !original_locked
      },
      format: :json
    }

    assert_response :success
    route.reload
    assert_equal original_locked, route.locked, 'locked should not be updated via driver_update'
  end

  test 'should not update route ref via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)
    original_ref = route.ref

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        stop_route_data_attributes: {
          status: 'completed'
        },
        ref: 'new_ref'
      },
      format: :json
    }

    assert_response :success
    route.reload
    assert_equal original_ref, route.ref, 'ref should not be updated via driver_update'
  end

  test 'should not update route color via driver_update' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)
    original_color = route.color

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        start_route_data_attributes: {
          status: 'completed'
        },
        color: '#FF0000'
      },
      format: :json
    }

    assert_response :success
    route.reload
    assert_equal original_color, route.color, 'color should not be updated via driver_update'
  end

  test 'should not update route status via update' do
    route = routes(:route_one_one)
    original_status = route.start_route_data.status

    patch :update, params: {
      id: route,
      route: {
        hidden: route.hidden,
        locked: route.locked,
        ref: route.ref,
        start_route_data: {
          status: 'completed'
        }
      }
    }

    assert_redirected_to route_path(assigns(:route))
    route.reload
    assert_equal original_status, route.start_route_data.status, 'status should not be updated via update'
  end

  test 'should handle driver_update failure gracefully' do
    vehicle = vehicles(:vehicle_one)
    route = routes(:route_one_one)
    Route.any_instance.stubs(:update).returns(false)
    Route.any_instance.stubs(:errors).returns(['Some error'])

    patch :driver_update, params: {
      id: route,
      driver_token: vehicle.driver_token,
      route: {
        start_route_data_attributes: {
          status: 'completed'
        }
      },
      format: :json
    }

    assert_response :unprocessable_entity
    assert_equal({ 'error' => I18n.t('routes.error_messages.update.failure') }, JSON.parse(response.body))
  end

  test 'should not allow driver_update without driver authentication' do
    route = routes(:route_one_one)

    patch :driver_update, params: {
      id: route,
      route: {
        start_route_data_attributes: {
          status: 'completed'
        }
      },
      format: :json
    }

    assert_response :forbidden
  end

  test 'should not allow driver_update with invalid driver token' do
    route = routes(:route_one_one)

    patch :driver_update, params: {
      id: route,
      driver_token: 'invalid_token',
      route: {
        start_route_data_attributes: {
          status: 'completed'
        }
      },
      format: :json
    }

    # Should redirect to login or return forbidden
    assert_response :redirect
  end
end
