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
    assert_includes description, '404'

    destination = swagger_definition(content, 'V01_Destination')
    assert destination, 'V01_Destination definition missing'
    %i[ref lat visits].each do |field|
      assert destination[:properties][field][:description].present?, "V01_Destination.#{field} should have a description"
    end

    visit = swagger_definition(content, 'V01_Visit')
    assert visit, 'V01_Visit definition missing'
    assert visit[:properties][:force_position][:description].present?, 'V01_Visit.force_position should have a description'

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
    assert_includes body, 'Job not found'
    assert_includes body, 'Accept-Language: en'
    assert_includes body, 'horaire début 1'
    assert_includes body, 'GET /plannings/:id/routes.json'

    php = Rails.root.join('public/api/0.1/examples/php/example.php').read
    refute_match(/"quantity"\s*:/, php)
    assert_includes php, "'delivery'"
    assert_includes php, 'Api-Key'

    ruby = Rails.root.join('public/api/0.1/examples/ruby/example.rb').read
    refute_match(/quantity:\s*1/, ruby)
    assert_includes ruby, 'delivery:'
    assert_includes ruby, 'Api-Key'
  end

  test 'should get version 100 swagger api doc' do
    get '/api/100/swagger_doc'

    assert_response :success

    content = JSON.parse(response.body, {:symbolize_names => true})
    assert_kind_of Hash, content
    assert_equal 'API', content[:info][:title]
  end

  private

  def swagger_definition(content, name)
    defs = content[:definitions] || content[:components] && content[:components][:schemas]
    return unless defs

    defs[name.to_sym] || defs.values.find { |schema| schema[:title].to_s.end_with?(name.delete_prefix('V01_')) }
  end
end
