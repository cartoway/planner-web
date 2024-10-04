RSpec.describe 'api_web/v01/plannings', type: :request do
  path '/api-web/0.1/plannings/{id}/edit' do
    parameter name: 'id', in: :path, type: :integer, description: 'Planning\'s id or ref (as "ref:[VALUE]") to be displayed, separated by commas'

    get('edit planning') do
      tags 'Plannings'
      produces 'text/html'
      description 'Edit all or some routes of one planning.'
      parameter name: :ids,
                description: 'Planning\'s routes ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
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

  path '/api-web/0.1/plannings/{id}/print' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('print planning') do
      tags 'Plannings'
      response(200, 'successful') do
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
