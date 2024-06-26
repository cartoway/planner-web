require 'swagger_helper'

RSpec.describe 'api_web/v01/stores', type: :request do
  path '/api-web/0.1/stores' do
    post('list stores') do
      tags 'Stores'
      produces 'text/html'
      description 'Display all or some stores.'
      parameter name: :ids,
                description: 'Store ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'text/html' => '<html><head></head><body><h1>Hello World<h1></body></html>'
          }
        end
        run_test!
      end
    end

    get('list stores') do
      tags 'Stores'
      produces 'text/html'
      description 'Display all or some stores.'
      parameter name: :ids,
                description: 'Store ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
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

  path '/api-web/0.1/stores/{id}/edit_position' do
    parameter name: 'id', in: :path, type: :integer, description: 'id'

    get('edit store position') do
      tags 'Stores'
      produces 'text/html'
      description 'Display a movable position marker of the destination.'
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

  path '/api-web/0.1/stores/{id}/update_position' do
    parameter name: 'id', in: :path, type: :integer, description: 'id'

    patch('update store position') do
      tags 'Stores'
      produces 'text/html'
      description 'Save the store position.'
      parameter name: 'lat', in: :query, type: :float
      parameter name: 'lng', in: :query, type: :float
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

  path '/api-web/0.1/stores/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show store') do
      tags 'Stores'
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
