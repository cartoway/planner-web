require 'swagger_helper'

RSpec.describe 'api_web/v01/stores', type: :request do

  path '/api-web/0.1/stores/by_distance' do

    get('by distance') do
      tags 'Stores'
      produces 'text/html'
      description 'Display the N closest stores of a point.'
      parameter name: 'lat', in: :query, type: :float
      parameter name: 'lng', in: :query, type: :float
      parameter name: 'n', in: :query, type: :integer
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'text/html' => '<html><head></head><body><h1>Hello World<h1></body></html>'
          }
        end
        run_test!
      end
    end
  end
end
