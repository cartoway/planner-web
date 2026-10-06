# frozen_string_literal: true

require 'test_helper'

class RecordStatusTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @stop = @operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'keeps the full timeline and does not regress the cursor' do
    t1 = Time.zone.parse('2026-09-25 10:00')
    t2 = Time.zone.parse('2026-09-25 11:00')
    t0 = Time.zone.parse('2026-09-25 09:00')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'started', recorded_at: t1, source: 'mobile')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'delivered', recorded_at: t2, source: 'mobile')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'planned', recorded_at: t0, source: 'mobile')

    @stop.reload
    assert_equal %w[planned started delivered], @stop.operation_stop_status_events.order(:recorded_at).pluck(:status)
    assert_equal 'delivered', @stop.status
    assert_equal t2, @stop.status_updated_at
    assert_nil @stop.stop.reload.status
  end

  test 'records status reset in the timeline and clears the cursor' do
    t1 = Time.zone.parse('2026-09-25 10:00')
    t2 = Time.zone.parse('2026-09-25 11:00')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'delivered', recorded_at: t1, source: 'mobile')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: nil, recorded_at: t2, source: 'mobile')

    @stop.reload
    assert_equal ['delivered', nil], @stop.operation_stop_status_events.order(:recorded_at).pluck(:status)
    assert_nil @stop.status
    assert_equal t2, @stop.status_updated_at
  end

  test 'does not allow resetting a transferred status' do
    target = @operation.operation_routes.planned.where.not(id: @stop.operation_route_id).detect { |route| route.route_id.present? }
    skip 'Need a second vehicle route' unless target
    OperationStops::Transfer.call(
      operation_stop: @stop,
      target_operation_route: target,
      recorded_at: Time.zone.parse('2026-09-25 12:00'),
      source: 'mobile'
    )

    assert_raises(ArgumentError) do
      OperationStops::RecordStatus.call(
        operation_stop: @stop.reload,
        status: nil,
        recorded_at: Time.zone.parse('2026-09-25 13:00'),
        source: 'mobile'
      )
    end
    assert_equal 'transferred', @stop.reload.status
  end

  test 'broadcasts a stop patch instead of a full page refresh' do
    operation = @stop.operation_route.operation
    Turbo::StreamsChannel.stubs(:broadcast_refresh_to)
    Turbo::StreamsChannel.expects(:broadcast_stream_to).at_least_once.with { |stream, kwargs|
      html = kwargs[:content].to_s
      stream == operation && html.include?('refresh_stop') && html.include?(@stop.id.to_s)
    }

    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'delivered', recorded_at: Time.zone.parse('2026-09-25 11:00'), source: 'mobile')
  end

  test 'stop patch carries status keys instead of translated labels' do
    content = nil
    Turbo::StreamsChannel.stubs(:broadcast_refresh_to)
    Turbo::StreamsChannel.stubs(:broadcast_stream_to).with { |_stream, kwargs|
      content = kwargs[:content].to_s
      true
    }
    I18n.with_locale(:en) do
      OperationStops::RecordStatus.call(operation_stop: @stop, status: 'delivered', recorded_at: Time.zone.parse('2026-09-25 11:00'), source: 'mobile')
    end
    json = CGI.unescapeHTML(content[%r{<template>(.*)</template>}m, 1].to_s)
    payload = JSON.parse(json)
    assert_equal 'delivered', payload['status']
    assert payload.dig('aside', 'kind')
    refute payload.key?('status_label')
    refute payload.key?('stops_label')
    refute payload.dig('aside', 'text')
    refute_includes json, I18n.t('operations.show.stops', locale: :en)
  end

  test 'board sums late minutes and ignores early arrivals' do
    route = @operation.operation_routes.includes(:operation_stops).detect { |candidate|
      candidate.operation_stops.count { |stop| stop.kind == 'visit' && stop.stop_snapshot['time'].present? } >= 2
    }
    assert route
    late, early = route.operation_stops.select { |stop| stop.kind == 'visit' && stop.stop_snapshot['time'].present? }.first(2)
    # Delay is vs planned departure (arrival + service), not arrival alone.
    late.update_columns(status: 'delivered', status_updated_at: late.planned_departure_at + 10.minutes)
    early.update_columns(status: 'delivered', status_updated_at: early.planned_departure_at - 8.minutes)

    assert_equal 10, route.board[:delay]
  end
end
