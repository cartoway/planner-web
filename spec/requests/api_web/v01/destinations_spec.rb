require 'swagger_helper'

RSpec.describe 'api_web/v01/destinations', type: :request do
  path '/api-web/0.1/destinations' do
    get('list destinations') do
      tags 'Destinations'
      produces 'text/html'
      description 'Display all or some destinations.'
      parameter name: :ids,
                description: 'Destination ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
      parameter name: :store_ids,
                description: 'Destination ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }

      parameter name: :disable_clusters, in: :query, type: :boolean,
                description: 'Set this disable_clusters parameter to true/1 to disable clusters on map.'
      response(200, 'successful') do
        let(:ids) { ['1', '2', '3'] }
        let(:store_ids) { ['1', '2', '3'] }
        let(:disable_clusters) { true }

        after do |example|
          example.metadata[:response][:content] = {
            'text/html' => '<html><head></head><body><h1>Hello World<h1></body></html>'
          }
        end
        run_test!
      end
    end
  end

  path '/api-web/0.1/destinations/{id}/edit_position' do
    parameter name: 'id', in: :path, type: :integer, description: 'id'
    get('edit destination position') do
      tags 'Destinations'
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

  path '/api-web/0.1/destinations/{id}/update_position' do
    parameter name: 'id', in: :path, type: :integer, description: 'id'
    patch('update destination position') do
      tags 'Destinations'
      produces 'text/html'
      description 'Save the destination position.'
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

  path '/api-web/0.1/destinations/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'
    get('show destination') do
      tags 'Destinations'
      produces 'text/html'
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
