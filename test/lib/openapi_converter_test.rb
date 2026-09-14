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
    assert_includes doc.dig('paths', '/0.1/destinations.json', 'post', 'tags'), 'core'
    assert_equal 'core', doc['tags'].first['name']
  end

  test 'tags admin and devices, scope core drops them and prunes unused schemas' do
    swagger = {
      'swagger' => '2.0',
      'info' => { 'title' => 'API', 'version' => '0.1' },
      'paths' => {
        '/0.1/destinations.json' => {
          'get' => {
            'tags' => ['destinations'],
            'responses' => { '200' => { 'description' => 'ok', 'schema' => { '$ref' => '#/definitions/V01_Destination' } } }
          }
        },
        '/0.1/customers.json' => {
          'get' => {
            'tags' => ['customers'],
            'responses' => { '200' => { 'description' => 'ok', 'schema' => { '$ref' => '#/definitions/V01_Customer' } } }
          }
        },
        '/0.1/devices/tomtom/sync.json' => {
          'get' => {
            'tags' => ['tomtom'],
            'responses' => { '200' => { 'description' => 'ok', 'schema' => { '$ref' => '#/definitions/V01_DeviceItem' } } }
          }
        }
      },
      'definitions' => {
        'V01_Destination' => { 'type' => 'object', 'properties' => { 'ref' => { 'type' => 'string' } } },
        'V01_Customer' => { 'type' => 'object' },
        'V01_DeviceItem' => { 'type' => 'object' }
      }
    }

    full = OpenapiConverter.convert(swagger)
    assert_includes full.dig('paths', '/0.1/customers.json', 'get', 'tags'), 'admin'
    assert_includes full.dig('paths', '/0.1/devices/tomtom/sync.json', 'get', 'tags'), 'devices'
    assert full.dig('components', 'schemas').key?('V01_DeviceItem')

    core = OpenapiConverter.convert(swagger, scope: 'core')
    assert core['paths'].key?('/0.1/destinations.json')
    refute core['paths'].key?('/0.1/customers.json')
    refute core['paths'].key?('/0.1/devices/tomtom/sync.json')
    assert core.dig('components', 'schemas').key?('V01_Destination')
    refute core.dig('components', 'schemas').key?('V01_Customer')
    refute core.dig('components', 'schemas').key?('V01_DeviceItem')
    names = core['tags'].map { |t| t['name'] }
    assert_includes names, 'core'
    refute_includes names, 'admin'
    refute_includes names, 'devices'
  end

  test 'marks leftover schema properties deprecated from their description' do
    swagger = {
      'swagger' => '2.0',
      'info' => { 'title' => 'API' },
      'paths' => {
        '/0.1/visits.json' => {
          'get' => {
            'responses' => { '200' => { 'description' => 'ok', 'schema' => { '$ref' => '#/definitions/V01_Visit' } } }
          }
        }
      },
      'definitions' => {
        'V01_Visit' => {
          'type' => 'object',
          'properties' => {
            'ref' => { 'type' => 'string' },
            'quantity' => { 'type' => 'integer', 'description' => 'Deprecated, use quantities instead.' }
          }
        }
      }
    }

    doc = OpenapiConverter.convert(swagger)
    assert_equal true, doc.dig('components', 'schemas', 'V01_Visit', 'properties', 'quantity', 'deprecated')
    refute doc.dig('components', 'schemas', 'V01_Visit', 'properties', 'ref').key?('deprecated')
  end
end
