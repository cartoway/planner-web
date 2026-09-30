# frozen_string_literal: true

require 'test_helper'

class OperationRouteMediaTest < ActionController::TestCase
  tests OperationRoutesController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_one)
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @operation_route = @operation.operation_routes.where(unassigned: false).first
    @stop = @operation_route.operation_stops.where(kind: 'visit').first
    @stop.photos.attach(
      io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
      filename: 'stop_photo.jpg',
      content_type: 'image/jpeg'
    )
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'lists photos for the route' do
    get :media, params: { operation_id: @operation.id, id: @operation_route.id }
    assert_response :success
    assert_includes response.body, 'operation-media-stage'
    assert_includes response.body, 'operation-media-edge'
  end

  test 'modal fragment groups documents by stop for navigation' do
    stops = @operation_route.operation_stops.executable.order(:index).to_a
    second = stops[1] || stops.first
    skip 'need at least one stop' unless second
    unless second.id == @stop.id
      second.photos.attach(
        io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
        filename: 'second_stop_photo.jpg',
        content_type: 'image/jpeg'
      )
    end

    get :media, params: { operation_id: @operation.id, id: @operation_route.id, modal: 1 }
    assert_response :success
    assert_includes response.body, 'operation-media-group'
    assert_includes response.body, 'data-media-group'
    assert_includes response.body, 'data-media-prev'
    assert_includes response.body, 'data-media-next'
    assert_includes response.body, 'stop_photo'
  ensure
    second.photos.purge if second && second.id != @stop.id && second.photos.attached?
  end
end
