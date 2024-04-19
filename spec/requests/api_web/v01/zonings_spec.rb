require 'swagger_helper'

RSpec.describe 'api_web/v01/zonings', type: :request do
  path '/api-web/0.1/zonings/{id}/edit' do
    parameter name: 'id', in: :path, type: :integer, description: 'Zonning ids'

    get('edit zoning') do
      tags 'Zonings'
      produces 'text/html'
      description 'Edit all or some zones of one zoning.'
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
