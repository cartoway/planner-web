require 'test_helper'

class ApiWebEmbedTokenTest < ActiveSupport::TestCase
  test 'issue and verify a token for the user' do
    issued = ApiWebEmbedToken.issue!(users(:user_one), expires_in: 120, origin: 'https://erp.example.com:8443')
    user, origin = ApiWebEmbedToken.verify(issued[:token])
    assert_equal users(:user_one).id, user.id
    assert_equal 'https://erp.example.com:8443', origin
    assert_in_delta 120, issued[:expires_at].to_i - Time.now.to_i, 2
  end

  test 'verify rejects garbage' do
    assert_nil ApiWebEmbedToken.verify('nope')
  end
end
