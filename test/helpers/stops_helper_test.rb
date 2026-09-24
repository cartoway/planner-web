require 'test_helper'

class StopsHelperTest < ActionView::TestCase
  test 'sms_uri_body percent-encodes spaces for iOS sms links' do
    encoded = sms_uri_body('Bonjour le monde')
    assert_equal 'Bonjour%20le%20monde', encoded
    refute_includes encoded, '+'
  end
end
