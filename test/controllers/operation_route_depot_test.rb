# frozen_string_literal: true

require 'test_helper'

class OperationRouteDepotTest < ActionController::TestCase
  tests OperationRoutesController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_one)
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @route = @operation.operation_routes.planned.first
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'depot fiche matches stop layout and rebuilds status history from stash' do
    day = @operation.date
    loading_at = Time.zone.local(day.year, day.month, day.day, 8, 10)
    finished_at = Time.zone.local(day.year, day.month, day.day, 8, 25)
    @route.update!(
      departure_status: 'finished',
      departure_status_updated_at: finished_at,
      custom_attributes: { '_departure_loading_at' => loading_at.iso8601 }
    )

    get :depot, params: { operation_id: @operation.id, id: @route.id, role: 'start' }

    assert_response :success
    assert_includes response.body, 'operation-stop-detail'
    assert_includes response.body, 'operation-times'
    assert_includes response.body, 'operation-timeline'
    assert_includes response.body, I18n.t('operations.show.arrival')
    assert_includes response.body, I18n.t('operations.show.departure')
    assert_includes response.body, I18n.t('operations.show.address')
    assert_includes response.body, I18n.t('plannings.edit.stop_store_status.atstore')
    assert_includes response.body, I18n.t('plannings.edit.stop_store_status.finished')
    assert_includes response.body, 'is-atstore'
    assert_includes response.body, 'is-finished is-latest'
    assert_select '.operation-timeline li', count: 2
    assert_not_includes response.body, '>atstore<'
  end

  test 'depot fiche shows empty timeline when depot has no status' do
    get :depot, params: { operation_id: @operation.id, id: @route.id, role: 'start' }

    assert_response :success
    assert_includes response.body, I18n.t('operations.show.no_status_history')
  end
end
