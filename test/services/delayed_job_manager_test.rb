require 'test_helper'

class DelayedJobManagerTest < ActiveSupport::TestCase
  test "should prevent duplicate jobs" do
    skip 'SimplifyGeojsonTracksJob is currently performed synchronously'
    original_delayed_job_use = Planner::Application.config.delayed_job_use
    Planner::Application.config.delayed_job_use = true

    DelayedJobManager.enqueue_simplify_geojson_tracks_job(1, 2)

    initial_job_count = Delayed::Job.count
    initial_job = Delayed::Job.last

    DelayedJobManager.enqueue_simplify_geojson_tracks_job(1, 2)

    assert_equal initial_job_count, Delayed::Job.count

    initial_job.reload
    assert initial_job.run_at > 29.seconds.from_now, "The job should be rescheduled with a delay of 30 seconds"
  ensure
    Planner::Application.config.delayed_job_use = original_delayed_job_use
  end

  test "should handle custom delay" do
    skip 'SimplifyGeojsonTracksJob is currently performed synchronously'
    original_delayed_job_use = Planner::Application.config.delayed_job_use
    Planner::Application.config.delayed_job_use = true

    DelayedJobManager.enqueue_simplify_geojson_tracks_job(1, 2, delay_seconds: 60)

    initial_job = Delayed::Job.last

    DelayedJobManager.enqueue_simplify_geojson_tracks_job(1, 2, delay_seconds: 60)

    initial_job.reload
    assert initial_job.run_at > 59.seconds.from_now, "The job should be rescheduled with a delay of 60 seconds"
  ensure
    Planner::Application.config.delayed_job_use = original_delayed_job_use
  end

  test "should handle generic job enqueue" do
    skip 'SimplifyGeojsonTracksJob is currently performed synchronously'
    original_delayed_job_use = Planner::Application.config.delayed_job_use
    Planner::Application.config.delayed_job_use = true

    DelayedJobManager.enqueue_with_delay(SimplifyGeojsonTracksJob, 1, 2)

    initial_job_count = Delayed::Job.count
    initial_job = Delayed::Job.last

    DelayedJobManager.enqueue_with_delay(SimplifyGeojsonTracksJob, 1, 2)

    assert_equal initial_job_count, Delayed::Job.count

    initial_job.reload
    assert initial_job.run_at > 29.seconds.from_now, "The job should be rescheduled with a delay of 30 seconds"
  ensure
    Planner::Application.config.delayed_job_use = original_delayed_job_use
  end

  test "should not create jobs when delayed_job_use is false" do
    original_delayed_job_use = Planner::Application.config.delayed_job_use
    Planner::Application.config.delayed_job_use = false

    initial_job_count = Delayed::Job.count

    result = DelayedJobManager.enqueue_simplify_geojson_tracks_job(1, 2)

    assert_equal initial_job_count, Delayed::Job.count
    assert_nil result
  ensure
    Planner::Application.config.delayed_job_use = original_delayed_job_use
  end
end
