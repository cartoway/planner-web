require 'test_helper'

class V01::GeocoderTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
  end

  def api(part, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/geocoder/#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should geocode' do
    get api(:search), {q: 'Rue des Poissons, Nantes'}
    assert last_response.ok?, last_response.body
    data = JSON.parse(last_response.body)
    assert 0 < data[0].size
  end
end
