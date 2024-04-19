require 'swagger_helper'

RSpec.describe 'api_web/v01/stops', type: :request do
  path '/api-web/0.1/stops/{id}' do
    parameter name: 'id', in: :path, type: :integer, description: 'Stop id'
    get('show stop') do
      tags 'Stops'
      produces 'text/html'
      description 'Show a stops details.'
      response(200, 'successful') do
        let(:id) { '123' }

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
