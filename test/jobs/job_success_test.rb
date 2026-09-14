require 'test_helper'

class JobSuccessTest < ActiveSupport::TestCase
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
end
