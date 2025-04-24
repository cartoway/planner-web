require 'test_helper'

class ExternalCallbackServiceTest < ActiveSupport::TestCase
  test "valid url makes successful request" do
    stub_request(:get, "https://example.com")
      .to_return(status: 200, body: "")

    service = ExternalCallbackService.new("https://example.com")
    response = service.call
    assert_equal 200, response.code
  end

  test "invalid url raises error" do
    service = ExternalCallbackService.new("not-a-url")
    assert_raises ExternalCallbackService::ExternalCallbackError do
      service.call
    end
  end
end
