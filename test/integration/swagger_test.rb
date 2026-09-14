require 'test_helper'

class SwaggerTest < ActionDispatch::IntegrationTest

  test 'should get swagger api doc' do
    get '/api/0.1/swagger_doc'

    assert_response :success

    content = JSON.parse(response.body, {:symbolize_names => true})
    assert_kind_of Hash, content
    assert_equal 'API', content[:info][:title]
  end

  test 'v0.1 swagger documents conventions, core entities and operations' do
    get '/api/0.1/swagger_doc'
    assert_response :success

    content = JSON.parse(response.body, symbolize_names: true)
    description = content.dig(:info, :description).to_s

    assert_includes description, 'Api-Key'
    assert_includes description, 'ref:'
    assert_includes description, '/jobs/'
    assert_includes description, 'getting-started.md'
    assert_includes description, 'succeeded'
    assert_includes description, 'openapi.json'

    destination = swagger_definition(content, 'V01_Destination')
    assert destination, 'V01_Destination definition missing'
    %i[ref lat visits].each do |field|
      assert destination[:properties][field][:description].present?, "V01_Destination.#{field} should have a description"
    end

    visit = swagger_definition(content, 'V01_Visit')
    assert visit, 'V01_Visit definition missing'
    assert visit[:properties][:force_position][:description].present?, 'V01_Visit.force_position should have a description'
    refute visit[:properties].key?(:quantity)
    refute visit[:properties].key?(:open1)

    operation_ids = content[:paths].values.flat_map { |path|
      path.values.filter_map { |op| op[:operationId] if op.is_a?(Hash) }
    }
    assert_includes operation_ids, 'getDestinations'
    assert_includes operation_ids, 'optimizeRoutes'
  end

  test 'getting started and samples document the happy path' do
    get '/api/0.1/getting-started.md'
    assert_response :success
    body = response.body.force_encoding('UTF-8')
    assert_includes body, '## Happy path'
    assert_includes body, '## Pitfalls'
    assert_includes body, 'status: "succeeded"'
    assert_includes body, 'Accept-Language: en'
    assert_includes body, 'horaire début 1'
    assert_includes body, 'GET /plannings/:id/routes.json'
    assert_includes body, 'openapi.json'
    assert_includes body, 'scope=core'
    assert_includes body, '/api/100'

    php = Rails.root.join('public/api/0.1/examples/php/example.php').read
    refute_match(/"quantity"\s*:/, php)
    assert_includes php, "'delivery'"
    assert_includes php, 'Api-Key'

    ruby = Rails.root.join('public/api/0.1/examples/ruby/example.rb').read
    refute_match(/quantity:\s*1/, ruby)
    assert_includes ruby, 'delivery:'
    assert_includes ruby, 'Api-Key'

    assert_includes body, 'Planner-API-0.1.collection.json'
  end

  test 'postman collection covers the happy path' do
    get '/api/0.1/examples/postman/Planner-API-0.1.collection.json'
    assert_response :success
    collection = JSON.parse(response.body)
    assert_equal 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json', collection.dig('info', 'schema')
    assert_equal 'apikey', collection.dig('auth', 'type')

    urls = flatten_postman_urls(collection['item'])
    %w[/deliverable_units.json /vehicles.json /destinations.json /plannings.json /optimize.json /jobs/ /routes.json].each do |fragment|
      assert urls.any? { |u| u.include?(fragment) }, "Postman collection missing #{fragment}"
    end

    env = JSON.parse(Rails.root.join('public/api/0.1/examples/postman/Planner-API-0.1.environment.json').read)
    keys = env['values'].map { |v| v['key'] }
    assert_includes keys, 'base'
    assert_includes keys, 'api_key'
    base = env['values'].find { |v| v['key'] == 'base' }['value']
    %w[development production].each do |env_name|
      config = Rails.root.join("config/environments/#{env_name}.rb").read
      swagger_base = config[/swagger_docs_base_path = ['"]([^'"]+)['"]/, 1]
      assert swagger_base, "swagger_docs_base_path missing in #{env_name}.rb"
      assert_equal swagger_base.chomp('/'), base, "Postman base should match swagger_docs_base_path in #{env_name}.rb"
    end
  end

  test 'should get version 100 swagger api doc' do
    get '/api/100/swagger_doc'

    assert_response :success

    content = JSON.parse(response.body, {:symbolize_names => true})
    assert_kind_of Hash, content
    assert_equal 'API', content[:info][:title]
    description = content.dig(:info, :description).to_s
    assert_includes description, 'openapi.json'
    assert_includes description, '0.1'
  end

  test 'should get OpenAPI 3 for 0.1' do
    get '/api/0.1/openapi.json'
    assert_response :success

    content = JSON.parse(response.body, symbolize_names: true)
    assert_equal '3.0.3', content[:openapi]
    refute content.key?(:swagger)
    assert content.dig(:components, :schemas).present?
    assert content[:paths].keys.any? { |path| path.to_s.include?('destinations') }
    assert content.dig(:servers, 0, :url).present?
    refute_match(/\/\z/, content.dig(:servers, 0, :url).to_s)
    destination_op = content[:paths].values.find { |item| item[:get] && item[:get][:operationId].to_s.include?('getDestinations') }
    assert destination_op, 'getDestinations missing from OpenAPI 3'
    assert_includes destination_op[:get][:tags], 'core'
    tag_names = Array(content[:tags]).map { |t| t[:name] }
    assert_includes tag_names, 'core'
    assert_includes tag_names, 'admin'
    assert_includes tag_names, 'devices'
  end

  test 'OpenAPI 3 scope core drops admin and devices' do
    get '/api/0.1/openapi.json?scope=core'
    assert_response :success

    content = JSON.parse(response.body, symbolize_names: true)
    paths = content[:paths].keys.map(&:to_s)
    assert paths.any? { |path| path.include?('destinations') }
    refute paths.any? { |path| path.include?('/devices/') }
    refute paths.any? { |path| path.match?(%r{/customers(\.json|/|\z)}) }
    tag_names = Array(content[:tags]).map { |t| t[:name] }
    assert_includes tag_names, 'core'
    refute_includes tag_names, 'admin'
    refute_includes tag_names, 'devices'
  end

  test 'should get OpenAPI 3 for 100' do
    get '/api/100/openapi.json'
    assert_response :success

    content = JSON.parse(response.body, symbolize_names: true)
    assert_equal '3.0.3', content[:openapi]
    refute content.key?(:swagger)
    assert content.dig(:components, :schemas).present?
    assert content[:paths].keys.any? { |path| path.to_s.include?('destinations') }
  end

  private

  def swagger_definition(content, name)
    defs = content[:definitions] || content[:components] && content[:components][:schemas]
    return unless defs

    defs[name.to_sym] || defs.values.find { |schema| schema[:title].to_s.end_with?(name.delete_prefix('V01_')) }
  end

  def flatten_postman_urls(items)
    Array(items).flat_map do |item|
      if item['item']
        flatten_postman_urls(item['item'])
      else
        url = item.dig('request', 'url')
        [url.is_a?(Hash) ? url['raw'] : url]
      end
    end.compact
  end
end
