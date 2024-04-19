RSpec.describe 'api_web/v01/routes', type: :request do
  path '/api-web/0.1/plannings/{planning_id}/routes' do
    parameter name: 'planning_id', in: :path, type: :integer, description: 'Planning id'
    get('list routes') do
      tags 'Routes'
      produces 'text/html'
      description 'Display all or some routes of one planning.'
      parameter name: :ids,
                description: 'Planning\'s routes ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
      response(200, 'successful') do
        let(:planning_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'text/html' => '<html><head></head><body><h1>Hello World<h1></body></html>'
          }
        end
        run_test!
      end
    end
  end

  path '/api-web/0.1/plannings/{planning_id}/routes/{id}/print' do
    parameter name: 'planning_id', in: :path, type: :string, description: 'planning_id'
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('print route') do
      tags 'Routes'
      response(200, 'successful') do
        let(:planning_id) { '123' }
        let(:id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              foo: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end
end
