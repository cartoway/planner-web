require 'test_helper'

class SwaggerTest < ActionDispatch::IntegrationTest

  test 'should get swagger api doc' do
    get '/api/0.1/swagger_doc'

    assert_response :success

    content = JSON.parse(response.body, {:symbolize_names => true})
    assert_kind_of Hash, content
    assert_equal 'API', content[:info][:title]
  end
end
