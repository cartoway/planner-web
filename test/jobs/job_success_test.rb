require 'test_helper'

class JobSuccessTest < ActiveSupport::TestCase
  test 'enqueuing an optimizer job records queued in last_async_jobs' do
    customer = customers(:customer_one)
    planning = plannings(:planning_one)
    customer.update!(last_async_jobs: {})

    delayed_job = Delayed::Job.enqueue(OptimizerJob.new(customer.id, planning.id, nil, {}))

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'queued', remembered['status']
    assert_equal planning.id, remembered['planning_id']
    assert_nil remembered['finished_at']
  end

  test 'optimizer before hook records working in last_async_jobs' do
    customer = customers(:customer_one)
    delayed_job = delayed_jobs(:job_optimizer)
    planning = plannings(:planning_one)

    OptimizerJob.new(customer.id, planning.id, nil, {}).before(delayed_job)

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'working', remembered['status']
    assert_nil remembered['finished_at']
  end

  test 'working last_async_jobs is visible during the worker transaction' do
    customer = customers(:customer_one)
    delayed_job = delayed_jobs(:job_optimizer)
    planning = plannings(:planning_one)
    customer.update!(last_async_jobs: {
      'optimizer' => { 'id' => delayed_job.id, 'type' => 'optimizer', 'status' => 'queued' }
    })

    Customer.transaction do
      OptimizerJob.new(customer.id, planning.id, nil, {}).before(delayed_job)
      seen = nil
      Thread.new { seen = Customer.find(customer.id).last_async_jobs.dig('optimizer', 'status') }.join
      assert_equal 'working', seen
      raise ActiveRecord::Rollback
    end

    assert_equal 'working', customer.reload.last_async_jobs.dig('optimizer', 'status')
  end

  test 'optimizer success records last_async_jobs for the customer' do
    customer = customers(:customer_one)
    delayed_job = delayed_jobs(:job_optimizer)
    planning = plannings(:planning_one)

    OptimizerJob.new(customer.id, planning.id, nil, {}).success(delayed_job)

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'optimizer', remembered['type']
    assert_equal 'succeeded', remembered['status']
    assert_equal planning.id, remembered['planning_id']
    assert remembered['finished_at'].present?
  end

  test 'optimizer failure records last_async_jobs for the customer' do
    customer = customers(:customer_one)
    delayed_job = delayed_jobs(:job_optimizer)
    delayed_job.update_column(:last_error, "VRPNoSolutionError: no solution\nbacktrace")
    planning = plannings(:planning_one)

    OptimizerJob.new(customer.id, planning.id, nil, {}).failure(delayed_job)

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'optimizer', remembered['type']
    assert_equal 'failed', remembered['status']
    assert_equal planning.id, remembered['planning_id']
    assert_equal 'VRPNoSolutionError: no solution', remembered['error']
    assert remembered['finished_at'].present?
  end

  test 'unrelated Job subclasses do not record last_async_jobs' do
    customer = customers(:customer_one)
    customer.update!(last_async_jobs: {})
    delayed_job = delayed_jobs(:job_optimizer)

    SimplifyGeojsonTracksJob.new(customer.id, 1).success(delayed_job)

    customer.reload
    assert_equal({}, customer.last_async_jobs)
  end

  test 'destroying an optimizer job records killed in last_async_jobs' do
    customer = customers(:customer_one)
    planning = plannings(:planning_one)
    delayed_job = Delayed::Job.enqueue(OptimizerJob.new(customer.id, planning.id, nil, {}))

    delayed_job.destroy

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'optimizer', remembered['type']
    assert_equal 'killed', remembered['status']
    assert remembered['finished_at'].present?
  end

  test 'successful job destroy does not overwrite last_async_jobs with killed' do
    customer = customers(:customer_one)
    planning = plannings(:planning_one)
    delayed_job = Delayed::Job.enqueue(OptimizerJob.new(customer.id, planning.id, nil, {}))

    OptimizerJob.new(customer.id, planning.id, nil, {}).success(delayed_job)
    delayed_job.destroy

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'succeeded', remembered['status']
  end

  test 'invoke_job then destroy records succeeded in last_async_jobs' do
    customer = customers(:customer_one)
    planning = plannings(:planning_one)
    customer.update!(last_async_jobs: {})
    delayed_job = Delayed::Job.enqueue(OptimizerJob.new(customer.id, planning.id, nil, {}))

    payload = delayed_job.payload_object
    payload.define_singleton_method(:perform) { true }
    delayed_job.invoke_job
    delayed_job.destroy

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'succeeded', remembered['status']
  end

  test 'destroying a failed optimizer job keeps failed in last_async_jobs' do
    customer = customers(:customer_one)
    planning = plannings(:planning_one)
    delayed_job = Delayed::Job.enqueue(OptimizerJob.new(customer.id, planning.id, nil, {}))
    delayed_job.update_columns(failed_at: Time.now.utc, last_error: "VRPNoSolutionError: no solution\nbacktrace")

    OptimizerJob.new(customer.id, planning.id, nil, {}).failure(delayed_job)
    Delayed::Job.find(delayed_job.id).destroy

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'failed', remembered['status']
    assert_equal 'VRPNoSolutionError: no solution', remembered['error']
  end

  test 'optimizer cancel records killed in last_async_jobs' do
    customer = customers(:customer_one)
    delayed_job = delayed_jobs(:job_optimizer)
    delayed_job.update_column(:last_error, "Optimization cancelled\nbacktrace")
    planning = plannings(:planning_one)

    OptimizerJob.new(customer.id, planning.id, nil, {}).failure(delayed_job)

    customer.reload
    remembered = customer.last_async_jobs['optimizer']
    assert_equal delayed_job.id, remembered['id']
    assert_equal 'killed', remembered['status']
    assert_nil remembered['error']
  end

  test 'killed last_async_jobs is not overwritten by a later fail for the same job' do
    customer = customers(:customer_one)
    delayed_job = delayed_jobs(:job_optimizer)
    planning = plannings(:planning_one)

    OptimizerJob.new(customer.id, planning.id, nil, {}).remember_async_job!(delayed_job, 'killed')
    delayed_job.update_column(:last_error, "VRPNoSolutionError: no solution\nbacktrace")
    OptimizerJob.new(customer.id, planning.id, nil, {}).failure(delayed_job)

    customer.reload
    assert_equal 'killed', customer.last_async_jobs['optimizer']['status']
  end
end
