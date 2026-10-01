# frozen_string_literal: true

require 'test_helper'

class DeliveryTrackingTest < ActionController::TestCase
  tests DeliveryTrackingsController

  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning, date: Date.current)
    @tracking = @operation.operation_delivery_trackings.first
    assert @tracking.present?
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'publish creates a tracking token per destination' do
    destination_ids = @operation.operation_stops.executable.where(kind: 'visit').where.not(destination_id: nil).distinct.pluck(:destination_id)
    assert_equal destination_ids.sort, @operation.operation_delivery_trackings.pluck(:destination_id).sort
    assert @tracking.token.present?
    assert_operator @tracking.expires_at, :>, Time.current
  end

  test 'tracking url is shortened when shortener is available' do
    long = Operations::TrackingUrl.long_for(@tracking)
    assert_includes long, "/s/#{@tracking.token}"
    short = Operations::TrackingUrl.for(@tracking)
    assert short.present?
  end

  test 'public page shows en route status' do
    stop = @tracking.visit_stops.first
    stop.update_columns(status: 'intransit', status_updated_at: Time.current)
    stop.operation_route.update_columns(departure_status: 'finished', departure_status_updated_at: Time.current)

    get :show, params: { token: @tracking.token }
    assert_response :success
    assert_includes response.body, I18n.t('delivery_trackings.chips.intransit')
  end

  test 'timeline drops on_site and timestamps depot steps' do
    stop = @tracking.visit_stops.first
    departed_at = Time.zone.parse("#{Date.current} 13:15")
    stop.operation_route.update_columns(departure_status: 'finished', departure_status_updated_at: departed_at)
    stop.update_columns(status: 'intransit', status_updated_at: Time.zone.parse("#{Date.current} 14:00"))

    get :show, params: { token: @tracking.token }
    assert_response :success
    assert_not_includes response.body, I18n.t('delivery_trackings.chips.on_site')
    assert_includes response.body, I18n.t('delivery_trackings.timeline.departed')
    assert_includes response.body, I18n.t('delivery_trackings.timeline.today_at', time: I18n.l(departed_at, format: :hour_minute))
    assert_includes response.body, I18n.t('delivery_trackings.show.title')
  end

  test 'upstream step mentions other planned stops' do
    visit_stops = @tracking.operation.operation_stops.executable.where(kind: 'visit').order(:index).to_a
    skip 'need at least two visits on the route' if visit_stops.size < 2

    later = visit_stops.last
    tracking = @operation.operation_delivery_trackings.find_by!(destination_id: later.destination_id)
    later.operation_route.update_columns(departure_status: 'finished', departure_status_updated_at: Time.current)
    later.update_columns(status: nil, status_updated_at: nil)
    visit_stops[0...-1].each { |s| s.update_columns(status: nil, status_updated_at: nil) if s.operation_route_id == later.operation_route_id }

    get :show, params: { token: tracking.token }
    assert_response :success
    assert_includes response.body, I18n.t('delivery_trackings.timeline.upstream_detail')
  end

  test 'public map uses the customer profile default base layer' do
    stop = @tracking.visit_stops.first
    stop.update_columns(lat: 48.85, lng: 2.35) if stop.lat.blank? || stop.lng.blank?

    layer = @operation.customer.profile.layers.order(:id).find_by!(overlay: false)
    get :show, params: { token: @tracking.token }
    assert_response :success
    assert_includes response.body, layer.translated_name
    assert_includes response.body, layer.url
  end

  test 'expired token shows dedicated page without delivery data' do
    @tracking.update_columns(expires_at: 1.hour.ago)
    get :show, params: { token: @tracking.token }
    assert_response :gone
    assert_includes response.body, I18n.t('delivery_trackings.expired.title')
    assert_not_includes response.body, I18n.t('delivery_trackings.chips.intransit')
  end

  test 'destination snapshot includes email' do
    destination = destinations(:destination_one)
    destination.update!(email: 'client@example.com', phone_number: '0600000000')
    snap = Operations::Snapshots.destination(destination)
    assert_equal 'client@example.com', snap['email']
  end
end
