require 'test_helper'

class StopsControllerTest < ActionController::TestCase

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |_url, _mode, _dimension, segments, _options| segments.collect { |_| [1000, 60, '_ibE_seK_seK_seK'] } }) do
      yield
    end
  end

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @stop = stops(:stop_one_one)
    @vehicle = vehicles(:vehicle_one)
    @planning = plannings(:planning_one)
    @route = routes(:route_one_one)
    @store = stores(:store_one)
    @stop_store = @route.add_store(@store)
    @stop_store.save!
    sign_in users(:user_one)
  end

  test 'should get one' do
    get :show, params: { id: @stop, format: :json }
    assert_response :success
    assert_valid response
  end

  # Tests for create_store action
  test 'should create stop store' do
    assert_difference('Stop.count', 1) do
      post :create_store, params: {
        planning_id: @planning.id,
        route_id: @route.id,
        store_id: @store.id,
        format: :json
      }
    end
    assert_response :success
  end

  test 'should handle create_store with invalid planning_id' do
    assert_difference('Stop.count', 0) do
      post :create_store, params: {
        planning_id: 99999,
        route_id: @route.id,
        store_id: @store.id,
        format: :json
      }
    end
    assert_response :not_found
  end

  test 'should handle create_store with invalid route_id' do
    assert_difference('Stop.count', 0) do
      post :create_store, params: {
        planning_id: @planning.id,
        route_id: 99999,
        store_id: @store.id,
        format: :json
      }
    end
    assert_response :not_found
  end

  test 'should handle create_store with invalid store_id' do
    assert_difference('Stop.count', 0) do
      post :create_store, params: {
        planning_id: @planning.id,
        route_id: @route.id,
        store_id: 99999,
        format: :json
      }
    end
    assert_response :not_found
  end

  # Tests for destroy action
  test 'should destroy StopStore' do
    assert_difference('Stop.count', -1) do
      delete :destroy, params: {
        planning_id: @planning.id,
        route_id: @route.id,
        stop_id: @stop_store.id,
        format: :js
      }
    end
    assert_response :success
  end

  test 'should handle destroy with StopVisit' do
    assert_difference('Stop.count', 0) do
      delete :destroy, params: {
        planning_id: @planning.id,
        route_id: @route.id,
        stop_id: @stop.id,
        format: :js
      }
    end
    assert_response :no_content
  end

  test 'should handle destroy with invalid stop_id' do
    assert_difference('Stop.count', 0) do
      delete :destroy, params: {
        planning_id: @planning.id,
        route_id: @route.id,
        stop_id: 99999,
        format: :js
      }
    end
    assert_response :not_found
  end

  test 'should handle destroy with invalid route_id' do
    assert_difference('Stop.count', 0) do
      delete :destroy, params: {
        planning_id: @planning.id,
        route_id: 99999,
        stop_id: @stop_store.id,
        format: :js
      }
    end
    assert_response :not_found
  end

  test 'should handle destroy with invalid planning_id' do
    assert_difference('Stop.count', 0) do
      delete :destroy, params: {
        planning_id: 99999,
        route_id: @route.id,
        stop_id: @stop_store.id,
        format: :js
      }
    end
    assert_response :not_found
  end

  # Tests for edit action
  test 'should get edit page for driver' do
    get :edit, params: { id: @stop, driver_token: @vehicle.driver_token }
    assert_response :success
  end

  test 'should not get edit page without driver authentication' do
    get :edit, params: { id: @stop }
    assert_redirected_to root_path
  end

  test 'should not get edit page with invalid driver token' do
    get :edit, params: { id: @stop, driver_token: 'invalid_token' }
    assert_redirected_to new_user_session_path
  end

  test 'should not get edit page with invalid stop id' do
    get :edit, params: { id: 99999, driver_token: @vehicle.driver_token }
    assert_response :not_found
  end

  # Tests for update action
  test 'should update stop status successfully' do
    patch :update, params: {
      id: @stop,
      driver_token: @vehicle.driver_token,
      stop: {
        status: 'completed',
        status_updated_at: 1.hour.from_now.iso8601
      },
      format: :json
    }
    assert_response :success
    assert_equal({ 'success' => true }, JSON.parse(response.body))
    @stop.reload
    assert_equal 'completed', @stop.status
  end

  test 'should update stop with custom attributes' do
    patch :update, params: {
      id: @stop,
      driver_token: @vehicle.driver_token,
      stop: {
        status: 'in_progress',
        status_updated_at: 1.hour.from_now.iso8601,
        custom_attributes: { 'custom_field' => 'custom_value' }
      },
      format: :json
    }
    assert_response :success
    assert_equal({ 'success' => true }, JSON.parse(response.body))
    @stop.reload
    assert_equal 'in_progress', @stop.status
    assert_equal 'custom_value', @stop.custom_attributes['custom_field']
  end

  test 'should not update stop without driver authentication' do
    patch :update, params: {
      id: @stop,
      stop: {
        status: 'completed',
        status_updated_at: 1.hour.from_now.iso8601
      },
      format: :json
    }
    assert_response :forbidden
    assert_equal({ 'error' => I18n.t('devise.failure.unauthenticated') }, JSON.parse(response.body))
  end

  test 'should not update stop with invalid driver token' do
    patch :update, params: {
      id: @stop,
      driver_token: 'invalid_token',
      stop: {
        status: 'completed',
        status_updated_at: 1.hour.from_now.iso8601
      },
      format: :json
    }
    assert_redirected_to new_user_session_path
  end

  test 'should not update stop with invalid id' do
    patch :update, params: {
      id: 99999,
      driver_token: @vehicle.driver_token,
      stop: {
        status: 'completed',
        status_updated_at: 1.hour.from_now.iso8601
      },
      format: :json
    }
    assert_response :not_found
  end

  test 'should not update stop with outdated status_updated_at' do
    @stop.update!(status_updated_at: 1.hour.ago)
    patch :update, params: {
      id: @stop,
      driver_token: @vehicle.driver_token,
      stop: {
        status: 'completed',
        status_updated_at: 2.hours.ago
      },
      format: :json
    }
    assert_response :conflict
  end

  test 'should handle update failure gracefully' do
    # Mock the update to fail
    Stop.any_instance.stubs(:update).returns(false)
    Stop.any_instance.stubs(:errors).returns(['Some error'])

    patch :update, params: {
      id: @stop,
      driver_token: @vehicle.driver_token,
      stop: {
        status: 'completed',
        status_updated_at: 1.hour.from_now.iso8601
      },
      format: :json
    }

    assert_response :unprocessable_entity
    assert_equal({ 'error' => I18n.t('stops.error_messages.update.failure') }, JSON.parse(response.body))
  end

  test 'should update stop without status_updated_at when nil' do
    @stop.update!(status_updated_at: nil)

    patch :update, params: {
      id: @stop,
      driver_token: @vehicle.driver_token,
      stop: {
        status: 'completed',
        status_updated_at: ''
      },
      format: :json
    }

    assert_response :success
    assert_equal({ 'success' => true }, JSON.parse(response.body))
  end

  test 'should update stop with current status_updated_at' do
    current_time = Time.current
    @stop.update!(status_updated_at: current_time)

    patch :update, params: {
      id: @stop,
      driver_token: @vehicle.driver_token,
      stop: {
        status: 'completed',
        status_updated_at: (current_time + 1.second).iso8601
      },
      format: :json
    }

    assert_response :success
    assert_equal({ 'success' => true }, JSON.parse(response.body))
  end
end
