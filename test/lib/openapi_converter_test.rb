require 'test_helper'

class OpenapiConverterTest < ActiveSupport::TestCase
  test 'converts swagger 2 definitions body params and refs to OAS 3' do
    swagger = {
      'swagger' => '2.0',
      'info' => { 'title' => 'API', 'version' => '0.1' },
      'basePath' => '/api',
      'paths' => {
        '/0.1/destinations.json' => {
          'post' => {
            'operationId' => 'createDestination',
            'parameters' => [
              {
                'name' => 'destination',
                'in' => 'body',
                'required' => true,
                'schema' => { '$ref' => '#/definitions/V01_Destination' }
              },
              { 'name' => 'api_key', 'in' => 'query', 'type' => 'string' }
            ],
            'responses' => {
              '201' => {
                'description' => 'Created',
                'schema' => { '$ref' => '#/definitions/V01_Destination' }
              }
            }
          }
        }
      },
      'definitions' => {
        'V01_Destination' => {
          'type' => 'object',
          'properties' => { 'ref' => { 'type' => 'string', 'x-nullable' => true } }
        }
      },
      'securityDefinitions' => {
        'api_key_header_param' => { 'type' => 'apiKey', 'name' => 'Api-Key', 'in' => 'header' }
      }
    }

    doc = OpenapiConverter.convert(swagger)

    assert_equal '3.0.3', doc['openapi']
    refute doc.key?('swagger')
    refute doc.key?('definitions')
    assert doc.dig('servers', 0, 'url').present?
    assert_equal '#/components/schemas/V01_Destination',
                 doc.dig('paths', '/0.1/destinations.json', 'post', 'requestBody', 'content', 'application/json', 'schema', '$ref')
    assert_equal '#/components/schemas/V01_Destination',
                 doc.dig('paths', '/0.1/destinations.json', 'post', 'responses', '201', 'content', 'application/json', 'schema', '$ref')
    assert_equal 'api_key', doc.dig('paths', '/0.1/destinations.json', 'post', 'parameters', 0, 'name')
    assert_equal 'string', doc.dig('paths', '/0.1/destinations.json', 'post', 'parameters', 0, 'schema', 'type')
    assert_equal true, doc.dig('components', 'schemas', 'V01_Destination', 'properties', 'ref', 'nullable')
    refute doc.dig('components', 'schemas', 'V01_Destination', 'properties', 'ref').key?('x-nullable')
    assert_equal 'apiKey', doc.dig('components', 'securitySchemes', 'api_key_header_param', 'type')
  end
end
