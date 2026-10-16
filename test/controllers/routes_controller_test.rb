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

  test 'should export route as excel via post body' do
    post :show, params: { id: @route, format: :excel, columns: 'ref|name|city', skips: 'comment', stops: 'store' }
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
end
