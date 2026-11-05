# frozen_string_literal: true

require 'test_helper'

class OperationsHelperTest < ActionView::TestCase
  test 'contact_rows_filled_count uses email or phone depending on channel' do
    rows = [
      { email: 'a@example.com', phone: '' },
      { email: '', phone: '0600000000' },
      { email: 'b@example.com', phone: '0611111111' }
    ]

    assert_equal 2, contact_rows_filled_count(rows, :email)
    assert_equal 2, contact_rows_filled_count(rows, :sms)
    assert_equal 0, contact_rows_filled_count(rows, :none)
  end

  test 'contact_rows_count_badge_class is green yellow or red by fill ratio' do
    assert_equal 'text-bg-success', contact_rows_count_badge_class(4, 4)
    assert_equal 'text-bg-warning', contact_rows_count_badge_class(4, 5)
    assert_equal 'text-bg-danger', contact_rows_count_badge_class(3, 4)
    assert_equal 'text-bg-danger', contact_rows_count_badge_class(0, 5)
  end

  test 'driver contact rows mark already_sent from last_sent_at' do
    sent = OperationRoute.new(id: 1, ref: 'A', last_sent_at: Time.current, vehicle_snapshot: { 'contact_email' => 'a@b.c' })
    sent.define_singleton_method(:vehicle_name) { 'Truck' }
    sent.define_singleton_method(:driver_email) { 'a@b.c' }
    sent.define_singleton_method(:driver_phone) { nil }

    fresh = OperationRoute.new(id: 2, ref: 'B', last_sent_at: nil, vehicle_snapshot: {})
    fresh.define_singleton_method(:vehicle_name) { 'Van' }
    fresh.define_singleton_method(:driver_email) { nil }
    fresh.define_singleton_method(:driver_phone) { '0600000000' }

    rows = operation_driver_contact_rows([sent, fresh])
    assert rows.first[:already_sent]
    assert_not rows.last[:already_sent]
  end

  test 'destination contact groups mark already_sent from stop last_sent_at' do
    tracking = OperationDeliveryTracking.new(id: 11, destination_id: 22)
    stop = OperationStop.new(id: 33, last_sent_at: Time.current, destination_snapshot: { 'email' => 'd@e.f' })
    dest = Struct.new(:name, :street, :email, :phone_number).new('Dest', '1 rue', 'd@e.f', nil)
    tracking.define_singleton_method(:visit_stops) { [stop] }
    tracking.define_singleton_method(:destination) { dest }
    OperationDeliveryTracking.stubs(:preload_visit_stops!)

    rows = operation_destination_contact_groups([tracking]).flat_map { |group| group[:rows] }
    assert_equal 1, rows.size
    assert rows.first[:already_sent]
  end
end
