require 'test_helper'

class StopsHelperTest < ActionView::TestCase
  test 'sms_uri_body percent-encodes spaces for iOS sms links' do
    encoded = sms_uri_body('Bonjour le monde')
    assert_equal 'Bonjour%20le%20monde', encoded
    refute_includes encoded, '+'
  end

  test 'delivery_note_quantity_label shows actual/planned only when they diverge' do
    assert_equal '20', delivery_note_quantity_label(20, 20)
    assert_equal '19/20', delivery_note_quantity_label(19, 20)
    half = number_with_precision(19.5, precision: 2, delimiter: t('number.format.delimiter'), strip_insignificant_zeros: true)
    assert_equal "#{half}/20", delivery_note_quantity_label(19.5, 20)
  end

  test 'approach sms replaces URL with delivery tracking link' do
    planning = plannings(:planning_one)
    operation = publish_operation!(planning: planning, date: Date.current)
    tracking = operation.operation_delivery_trackings.first
    stop = tracking.visit_stops.first
    assert stop.present?

    customer = operation.customer
    customer.update!(sms_intransit_template: 'Suivi {URL}')
    shortener = Object.new
    shortener.define_singleton_method(:shorten) { |url| "http://short.test/#{url.split('/').last}" }
    Rails.application.config.stubs(:url_shortener).returns(shortener)

    result = formatted_stop_inroute_sms(stop)
    assert_equal "Suivi http://short.test/#{tracking.token}", result[:content]
  ensure
    Operation.where(customer_id: planning.customer_id).delete_all if planning
  end
end
