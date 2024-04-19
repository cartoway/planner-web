require 'swagger_helper'

RSpec.describe 'api_web/v01/zones', type: :request do
  path '/api-web/0.1/zonings/{zoning_id}/zones' do
    parameter name: 'zoning_id', in: :path, type: :integer, description: 'zoning_id'
    get('list zones') do
      tags 'Zones'
      produces 'text/html'
      description 'Display all or some zones of one zoning. If vehicle_usage_set_id or planning_id or only one ' \
                  'vehicle_usage_set present, then filter store by associated VehicleUsageSet''s VehicleUsage.'
      parameter name: :ids,
                description: 'Zoning\'s zones ids to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
      parameter name: :destinations, in: :query, type: :boolean,
                description: 'Destinations displayed or not, no destinations by default'
      parameter name: :destination_ids,
                description: 'Destination ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
      parameter name: :store_ids,
                description: 'Store ids or refs (as "ref:[VALUE]") to be displayed, separated by commas',
                in: :query, type: 'array', items: { type: 'string' }
      parameter name: :vehicle_usage_set_id, in: :query, type: :integer,
                description: 'VehicleUsageSet id (used to filter stores)'
      parameter name: :planning_id, in: :query, type: :integer,
                description: 'Planning id (used to filter stores)'

      response(200, 'successful') do
        let(:zoning_id) { '123' }

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
