require 'test_helper'

class V01::TagsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @tag = tags(:tag_one)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/tags#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  def api_tags(tag_id_ref)
    "/api/0.1/tags/#{tag_id_ref}/visits?api_key=testkey1"
  end

  test "should return customer's tags" do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @tag.customer.tags.size, JSON.parse(last_response.body).size
  end

  test "should return customer's tags by ids" do
    get api(nil, 'ids' => "#{@tag.id},ref:#{tags(:tag_two).ref}")
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal 2, body.size
    assert_includes(body.map { |p| p['id'] }, @tag.id)
    assert_includes(body.map { |p| p['ref'] }, tags(:tag_two).ref)
  end

  test 'should return a tag' do
    get api(@tag.id)
    assert last_response.ok?, last_response.body
    assert_equal @tag.label, JSON.parse(last_response.body)['label']
  end

  test 'should return a tag  by reference' do
    get api(nil, 'ids' => "#{@tag.id},ref:#{tags(:tag_two).ref}")
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal 2, body.size
    assert_includes(body.map { |p| p['id'] }, @tag.id)
    assert_includes(body.map { |p| p['ref'] }, tags(:tag_two).ref)
  end

  test 'should create a tag' do
    assert_difference('Tag.count', 1) do
      @tag.label = 'new label'
      post api(), @tag.attributes
      assert last_response.created?, last_response.body
    end
  end

  test 'should create a tag without icon' do
    @tag.icon = '' # Use default icon instead
    @tag.label = 'New label'
    post api(), @tag.attributes
    assert_equal 201, last_response.status
    response = JSON.parse(last_response.body)
    assert_nil response[:icon]
    assert_not_nil @tag.reload.default_icon
  end

  test 'should not create if not a font awesome icon' do
    @tag.icon = 'not-icon' # Invalid as font-awesome
    post api(), @tag.attributes
    assert_equal 400, last_response.status, 'Bad response: ' + last_response.body
    response = JSON.parse(last_response.body)
    assert_match(I18n.t('activerecord.errors.models.tag.icon_unknown'), response['message'])
  end

  test 'should update a tag' do
    @tag.label = 'new label'
    put api(@tag.id), label: 'riri', color: '#123456', icon_size: 'large'
    assert last_response.ok?, last_response.body

    get api(@tag.id)
    assert last_response.ok?, last_response.body
    assert_equal 'riri', JSON.parse(last_response.body)['label']
    assert_equal '#123456', JSON.parse(last_response.body)['color']
    assert_equal 'large', JSON.parse(last_response.body)['icon_size']
  end

  test 'should destroy a tag' do
    assert_difference('Tag.count', -1) do
      delete api(@tag.id)
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy multiple tags' do
    assert_difference('Tag.count', -2) do
      delete api + "&ids=#{tags(:tag_one).id},ref:#{tags(:tag_two).ref}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should update outdated' do
    tag = tags :tag_one
    assert_not tag.visits[0].stop_visits[-1].route.outdated
    tag.icon = 'fa-bolt'
    tag.save!
    assert tag.visits[0].stop_visits[-1].route.reload.outdated # Reload route because it not updated in main scope
  end

  test 'Should return visits with tag_ref' do
    @tag.update ref: 'tag_1'
    get api_tags("ref:#{@tag.ref}")
    assert last_response.ok?, last_response.body
    assert_equal 4, JSON.parse(last_response.body).size
  end

  test 'Should return visits with tag_id' do
    get api_tags(@tag.id)
    @tag.update ref: 'tag_1'
    assert last_response.ok?, last_response.body
    assert_equal 4, JSON.parse(last_response.body).size
  end

  test 'Should return empty list with invalid tag id/ref' do
    @tag.update ref: 'tag_1'
    get api_tags(-1)
    assert last_response.ok?, last_response.body
    assert_equal 0, JSON.parse(last_response.body).size
  end
end
