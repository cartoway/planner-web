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
end
