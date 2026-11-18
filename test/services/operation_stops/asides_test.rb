# frozen_string_literal: true

require 'test_helper'

class OperationStops::AsidesTest < ActiveSupport::TestCase
  StubStop = Struct.new(
    :delay_minutes, :time_window_delay_minutes, :phase, :kind, :treated, :status_label,
    keyword_init: true
  ) do
    def treated? = treated
  end

  def asides_for(**attrs)
    OperationStops::Asides.call(StubStop.new(treated: true, status_label: 'Livré', kind: 'visit', **attrs))
  end

  test 'window late plus large plan gap' do
    asides = asides_for(delay_minutes: 140, time_window_delay_minutes: 20, phase: 'delivered')
    assert_equal %w[window_late plan_gap], asides.map { |a| a[:kind] }
    assert_equal [20, 140], asides.map { |a| a[:count] }
    I18n.with_locale(:fr) do
      assert_equal 'Retard +20 min', asides.first[:label]
      assert_equal 'Écart +140 min', asides.last[:label]
    end
  end

  test 'delivered on plan with window late keeps status' do
    asides = asides_for(delay_minutes: 0, time_window_delay_minutes: 15, phase: 'delivered')
    assert_equal %w[window_late status], asides.map { |a| a[:kind] }
  end

  test 'delivered early with window late keeps status' do
    asides = asides_for(delay_minutes: -8, time_window_delay_minutes: 15, phase: 'delivered')
    assert_equal %w[window_late status], asides.map { |a| a[:kind] }
  end

  test 'delivered on plan without window shows status only' do
    asides = asides_for(delay_minutes: 0, time_window_delay_minutes: 0, phase: 'delivered')
    assert_equal %w[status], asides.map { |a| a[:kind] }
  end

  test 'small plan gap uses plan_gap kind with ok tone' do
    asides = asides_for(delay_minutes: 3, time_window_delay_minutes: 0, phase: 'delivered')
    assert_equal ['plan_gap'], asides.map { |a| a[:kind] }
    assert_equal :ok, asides.first[:tone]
  end

  test 'failed phase is a single bad status badge' do
    asides = asides_for(phase: 'failed', status_label: 'Échec', delay_minutes: nil, time_window_delay_minutes: nil)
    assert_equal ['status'], asides.map { |a| a[:kind] }
    assert_equal :bad, asides.first[:tone]
  end
end
