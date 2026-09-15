require 'test_helper'

class V01::EmbedTokensTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  test 'should create an embed token' do
    post '/api/0.1/embed_tokens.json?api_key=testkey1', { origin: 'https://erp.example.com', expires_in: 120 }
    assert_equal 201, last_response.status, last_response.body
    body = JSON.parse(last_response.body)
    assert body['token'].present?
    assert_equal 'https://erp.example.com', body['origin']
    user, origin = ApiWebEmbedToken.verify(body['token'])
    assert_equal users(:user_one).id, user.id
    assert_equal 'https://erp.example.com', origin
  end

  test 'should reject an invalid origin' do
    post '/api/0.1/embed_tokens.json?api_key=testkey1', { origin: 'not a url' }
    assert_equal 400, last_response.status, last_response.body
  end
end
