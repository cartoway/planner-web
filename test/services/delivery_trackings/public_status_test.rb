# frozen_string_literal: true

require 'test_helper'

class DeliveryTrackingsPublicStatusTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning, date: Date.current)
    @tracking = @operation.operation_delivery_trackings.first
    @stop = @tracking.visit_stops.first
    @route = @stop.operation_route
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'departed step stays pending until route departure is finished' do
    @route.update_columns(departure_status: 'atstore', departure_status_updated_at: Time.current)
    @stop.update_columns(status: nil, status_updated_at: nil)

    departed = timeline_step('departed')
    assert_equal 'pending', departed[:state]

    @route.update_columns(departure_status: 'intransit', departure_status_updated_at: Time.current)
    departed = timeline_step('departed')
    assert_equal 'pending', departed[:state]

    finished_at = Time.zone.parse("#{Date.current} 13:15")
    @route.update_columns(departure_status: 'finished', departure_status_updated_at: finished_at)
    departed = timeline_step('departed')
    assert_equal 'done', departed[:state]
    assert_includes departed[:detail], I18n.l(finished_at, format: :hour_minute)

    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'departed', visit.chip_key
    assert_equal 'current', visit.timeline.find { |step| step[:key] == 'intransit' }[:state]

    @stop.update_columns(status: 'intransit', status_updated_at: Time.current)
    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'intransit', visit.chip_key
    departed = timeline_step('departed')
    assert_equal 'done', departed[:state]
    assert_includes departed[:detail], I18n.l(finished_at, format: :hour_minute)
  end

  test 'done loading step shows status time not upcoming' do
    loading_at = Time.zone.parse("#{Date.current} 12:50")
    finished_at = Time.zone.parse("#{Date.current} 13:15")
    @route.update_columns(
      departure_status: 'finished',
      departure_status_updated_at: finished_at,
      custom_attributes: { '_departure_loading_at' => loading_at.iso8601 }
    )
    @stop.update_columns(status: nil, status_updated_at: nil)

    loading = timeline_step('loading')
    assert_equal 'done', loading[:state]
    assert_includes loading[:detail], I18n.l(loading_at, format: :hour_minute)
    assert_not_equal I18n.t('delivery_trackings.timeline.upcoming'), loading[:detail]
  end

  test 'departed uses the last store stop before the visit when reloads exist' do
    @route.operation_stops.create!(
      kind: 'store',
      index: @stop.index - 2,
      sync_state: 'active',
      active: true,
      status: 'finished',
      status_updated_at: 2.hours.ago,
      store_snapshot: { 'name' => 'Depot A' }
    )
    later = @route.operation_stops.create!(
      kind: 'store',
      index: @stop.index - 1,
      sync_state: 'active',
      active: true,
      status: 'atstore',
      status_updated_at: 1.hour.ago,
      store_snapshot: { 'name' => 'Reload B' }
    )
    @route.update_columns(departure_status: 'finished', departure_status_updated_at: 3.hours.ago)
    @stop.update_columns(status: nil, status_updated_at: nil)

    departed = timeline_step('departed')
    assert_equal 'pending', departed[:state], 'must wait for the last preceding store, not route start'

    finished_at = Time.zone.parse("#{Date.current} 14:05")
    later.update_columns(status: 'finished', status_updated_at: finished_at)
    @stop.update_columns(status: 'intransit', status_updated_at: Time.current)
    departed = timeline_step('departed')
    assert_equal 'done', departed[:state]
    assert_includes departed[:detail], I18n.l(finished_at, format: :hour_minute)
  end

  test 'eta window uses customer gaps and quarter rounding' do
    customer = @operation.customer
    customer.update!(delivery_tracking_eta_gap_before: 5, delivery_tracking_eta_gap_after: 15)
    # 10:07 planned → 10:02 / 10:22 → rounded 10:00 – 10:15
    snap = (@stop.stop_snapshot || {}).merge('time' => 10.hours + 7.minutes)
    @stop.update_columns(stop_snapshot: snap, status: nil, status_updated_at: nil)

    travel_to Time.zone.parse("#{Date.current} 09:00") do
      visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
      assert_equal '10:00 – 10:15', visit.eta_window
    end
  end

  test 'eta window shifts with delay from last treated operation stop' do
    customer = @operation.customer
    customer.update!(delivery_tracking_eta_gap_before: 5, delivery_tracking_eta_gap_after: 15)

    prior = @route.operation_stops.create!(
      kind: 'visit',
      index: @stop.index - 1,
      sync_state: 'active',
      active: true,
      status: 'delivered',
      status_updated_at: Time.zone.parse("#{Date.current} 10:20"),
      stop_snapshot: { 'time' => 10.hours },
      visit_snapshot: { 'ref' => 'prior' },
      destination_snapshot: { 'name' => 'Prior' }
    )
    snap = (@stop.stop_snapshot || {}).merge('time' => 11.hours)
    @stop.update_columns(stop_snapshot: snap, status: nil, status_updated_at: nil)

    # delay +20min → centre 11:20 → 11:15 – 11:35 → rounded 11:15 – 11:30
    travel_to Time.zone.parse("#{Date.current} 10:30") do
      visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
      assert_equal '11:15 – 11:30', visit.eta_window
      assert prior.treated?
    end
  end

  test 'eta window shifts from route departure depot delay' do
    customer = @operation.customer
    customer.update!(delivery_tracking_eta_gap_before: 5, delivery_tracking_eta_gap_after: 15)

    snap = (@route.route_snapshot || {}).merge('start' => 14.hours)
    @route.update_columns(
      route_snapshot: snap,
      departure_status: 'finished',
      departure_status_updated_at: Time.zone.parse("#{Date.current} 16:15")
    )
    stop_snap = (@stop.stop_snapshot || {}).merge('time' => 14.hours + 15.minutes)
    @stop.update_columns(stop_snapshot: stop_snap, status: nil, status_updated_at: nil)

    # delay +2h15 → centre 16:30 → 16:25 – 16:45 → rounded 16:30 – 16:45
    travel_to Time.zone.parse("#{Date.current} 16:00") do
      visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
      assert_equal '16:30 – 16:45', visit.eta_window
    end
  end

  test 'past eta max shows imminent while route still open' do
    customer = @operation.customer
    customer.update!(delivery_tracking_eta_gap_before: 5, delivery_tracking_eta_gap_after: 15)
    @route.update_columns(arrival_status: nil)
    stop_snap = (@stop.stop_snapshot || {}).merge('time' => 10.hours)
    @stop.update_columns(stop_snapshot: stop_snap, status: 'intransit', status_updated_at: Time.current)

    travel_to Time.zone.parse("#{Date.current} 12:00") do
      visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
      assert_equal I18n.t('delivery_trackings.show.imminent'), visit.eta_window
      intransit = visit.timeline.find { |step| step[:key] == 'intransit' }
      assert_equal I18n.t('delivery_trackings.show.imminent'), intransit[:detail]
    end
  end

  test 'finished route without delivery marks missed steps' do
    customer = @operation.customer
    customer.update!(delivery_tracking_eta_gap_before: 5, delivery_tracking_eta_gap_after: 15)
    @route.update_columns(
      arrival_status: 'finished',
      arrival_status_updated_at: Time.current,
      departure_status: 'finished',
      departure_status_updated_at: Time.zone.parse("#{Date.current} 09:00")
    )
    stop_snap = (@stop.stop_snapshot || {}).merge('time' => 10.hours)
    @stop.update_columns(stop_snapshot: stop_snap, status: nil, status_updated_at: nil)

    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'missed', visit.chip_key
    assert_equal I18n.t('delivery_trackings.show.undelivered'), visit.eta_window
    assert_nil visit.timeline.find { |step| step[:key] == 'intransit' }
    assert_equal 'done', visit.timeline.find { |step| step[:key] == 'departed' }[:state]
    failedish = visit.timeline.select { |step| step[:state] == 'failed' }
    assert failedish.any?
    assert failedish.all? { |step| step[:detail] == I18n.t('delivery_trackings.show.undelivered') }
  end

  test 'failed stop omits en route timeline step' do
    finished_at = Time.zone.parse("#{Date.current} 09:14")
    @route.update_columns(departure_status: 'finished', departure_status_updated_at: finished_at)
    @stop.update_columns(status: 'undelivered', status_updated_at: Time.current)

    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'failed', visit.chip_key
    assert_nil visit.timeline.find { |step| step[:key] == 'intransit' }
    failed = visit.timeline.find { |step| step[:key] == 'failed' }
    assert_equal 'failed', failed[:state]
    assert_equal I18n.t('delivery_trackings.timeline.failed_detail'), failed[:detail]
    loading = visit.timeline.find { |step| step[:key] == 'loading' }
    departed = visit.timeline.find { |step| step[:key] == 'departed' }
    assert_equal 'done', loading[:state]
    assert_equal 'done', departed[:state]
    assert_includes departed[:detail], I18n.l(finished_at, format: :hour_minute)
  end

  test 'failed visit marks depot done even without departure cursor' do
    @route.update_columns(departure_status: nil, departure_status_updated_at: nil)
    @stop.update_columns(status: 'undelivered', status_updated_at: Time.zone.parse("#{Date.current} 10:05"))

    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'done', visit.timeline.find { |step| step[:key] == 'loading' }[:state]
    assert_equal 'done', visit.timeline.find { |step| step[:key] == 'departed' }[:state]
    assert_equal 'failed', visit.timeline.find { |step| step[:key] == 'failed' }[:state]
  end

  test 'delivered terminal step is done not current' do
    delivered_at = Time.zone.parse("#{Date.current} 11:40")
    @stop.update_columns(status: 'delivered', status_updated_at: delivered_at)

    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'delivered', visit.chip_key
    assert_nil visit.timeline.find { |step| step[:key] == 'intransit' }
    delivered = visit.timeline.find { |step| step[:key] == 'delivered' }
    assert_equal 'done', delivered[:state]
    assert_includes delivered[:detail], I18n.l(delivered_at, format: :hour_minute)
  end

  test 'exception terminal step is alert with message' do
    @stop.update_columns(status: 'exception', status_updated_at: Time.current)

    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'exception', visit.chip_key
    assert_nil visit.timeline.find { |step| step[:key] == 'intransit' }
    alert = visit.timeline.find { |step| step[:key] == 'exception' }
    assert_equal 'alert', alert[:state]
    assert_equal I18n.t('delivery_trackings.timeline.exception_detail'), alert[:detail]
  end

  test 'upstream step is current when depot departed and stops remain before' do
    prior = @route.operation_stops.create!(
      kind: 'visit',
      index: @stop.index - 1,
      sync_state: 'active',
      active: true,
      status: nil,
      stop_snapshot: { 'time' => 10.hours },
      visit_snapshot: { 'ref' => 'prior' },
      destination_snapshot: { 'name' => 'Prior' }
    )
    @route.update_columns(departure_status: 'finished', departure_status_updated_at: Time.current)
    @stop.update_columns(status: nil, status_updated_at: nil)

    visit = DeliveryTrackings::PublicStatus.new(@tracking.reload).visits.find { |item| item.stop.id == @stop.id }
    assert_equal 'departed', visit.chip_key
    assert_operator visit.stops_before, :>, 0
    upstream = visit.timeline.find { |step| step[:key] == 'upstream' }
    intransit = visit.timeline.find { |step| step[:key] == 'intransit' }
    assert_equal 'current', upstream[:state]
    assert_equal 'pending', intransit[:state]
    assert prior.persisted?
  end

  private

  def timeline_step(key)
    view = DeliveryTrackings::PublicStatus.new(@tracking.reload)
    visit = view.visits.find { |item| item.stop.id == @stop.id }
    visit.timeline.find { |step| step[:key] == key }
  end
end
