require 'test_helper'

class V100::PlanningsBaseTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/100/plannings#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end
end

class V100::PlanningsTest < V100::PlanningsBaseTest
  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda{ |url, mode, dimensions, row, column, options| [Array.new(row.size) { Array.new(column.size, 0) }] }) do
        # return all services in reverse order in first route, rests at the end
        OptimizerWrapper.stub_any_instance(:optimize, lambda { |positions, services, vehicles, options| [[]] + vehicles.each_with_index.map{ |v, i| ((i.zero? ? services.reverse : []) + v[:rests]).map{ |s| s[:stop_id] }} }) do
          yield
        end
      end
    end
  end

  test 'should automatic insert stop with ID from unassigned' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
      patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true }.to_json, CONTENT_TYPE: 'application/json'
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 201, last_response.status, last_response.body
        content = JSON.parse(last_response.body, symbolize_names: true)
        assert content[:routes].any?{ |route| route[:stops].select{ |st| st[:active] }.map{ |st| st[:id] }.include?(unassigned_stop.id) }
        @planning.routes.select(&:vehicle_usage).each{ |vu|
          assert_not vu.outdated
        }
      end
    end
  end

  test 'should automatic insert stop with Ref from existing route with vehicle' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      last_stop = routes(:route_one_one).stops.select(&:position?).last
      last_stop.update! active: false

      patch api("ref:#{@planning.ref}/automatic_insert"), nil, input: { stop_ids: [last_stop.id], out_of_zone: true }.to_json, CONTENT_TYPE: 'application/json'
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 201, last_response.status, last_response.body
        content = JSON.parse(last_response.body, symbolize_names: true)
        assert content[:routes].any?{ |route| route[:stops].select{ |st| st[:active] }.map{ |st| st[:id] }.include?(last_stop.id) }
        assert content[:routes].all?{ |r| r[:stops].map{ |st| st[:index] }.sum == (r[:stops].length * (r[:stops].length + 1)) / 2 }
      end
    end
  end

  test 'should automatic insert taking into account only active or all stops' do
    customers(:customer_one).update(job_optimizer_id: nil)
    Vehicle.all.each{ |v| v.update tags: [] }

    # 0. Init all stops inactive
    @planning.routes.each{ |r| r.stops.each{ |s| s.update! active: false } }
    @planning.reload
    unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first

    # 1. First insert with active_only = true
    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true, active_only: false }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 201, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }

    stop = @planning.routes.flat_map{ |r| r.stops.select{ |s| s.id == unassigned_stop.id } }.compact.first
    stop_compare = [stop.route_id, stop.index]

    # 2. Move back stop to original route
    @planning.move_stop(@planning.routes.detect{ |route| !route.vehicle_usage }, stop, nil)
    @planning.routes.each{ |r| r.compute && r.save! }
    @planning.save!

    # 3. Init all stops active
    @planning.routes.each{ |r| r.stops.each{ |s| s.update! active: true } }
    @planning.reload
    unassigned_stop = @planning.reload.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first

    # 4. Second insert with active_only = false
    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true, active_only: true }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 201, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }

    # 5. Route or index should be different between automatic insert
    stop = @planning.routes.flat_map{ |r| r.stops.select{ |s| s.id == unassigned_stop.id } }.compact.first
    assert_not_equal stop_compare, [stop.route_id, stop.index]
  end

  test 'should automatic insert or not with max time' do
    customers(:customer_one).update(job_optimizer_id: nil)
    unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first

    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_time: 50_000 }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 400, last_response.status
    assert_not @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id)}

    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_time: 100_000 }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 201, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }
  end

  test 'should automatic insert or not with max distance' do
    customers(:customer_one).update(job_optimizer_id: nil)
    unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
    # Fixtures route time and distance are 1.5 (and should be updated)
    @planning.routes.each{ |r| r.outdated = true }

    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_distance: 500}.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 400, last_response.status
    assert_not @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id)}

    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_distance: 2_001}.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 201, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }
  end

  test 'should automatic insert with error' do
    customers(:customer_one).update(job_optimizer_id: nil)
    Route.stub_any_instance(:compute, lambda{ |*a| raise }) do
      unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
      assert_no_difference('Stop.count') do
        patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true }.to_json, CONTENT_TYPE: 'application/json'
        assert_equal 500, last_response.status
        assert @planning.routes.reload.detect{ |route| !route.vehicle_usage }.stop_ids.include?(unassigned_stop.id)
      end
    end
  end
end
