require 'test_helper'

class V100::PlanningsDestinationsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActionDispatch::TestProcess

  def app
    Rails.application
  end

  setup do
    @destination = destinations(:destination_one)
    @planning = plannings(:planning_one)
    @planning.customer.update(job_optimizer_id: nil)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  def api(planning_id, part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/100/plannings/#{planning_id}/destinations#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should return 404 with invalid destination id' do
    get api(plannings(:planning_two).id, "/#{destinations(:destination_four).id}/candidate_insert")
    assert_equal 404, last_response.status
  end

  test 'should return candidate route' do
    get api(@planning.id, "#{@destination.id}/candidate_insert")
    assert_equal 201, last_response.status, last_response.body
    data = JSON.parse(last_response.body)
    assert_kind_of Integer, data['distance']
    assert_kind_of Integer, data['time']
    assert_kind_of Integer, data['index']
    assert_kind_of Hash, data['route']
  end
end
