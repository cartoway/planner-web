require 'delayed_job_progress_parser'

Delayed::Job.include DelayedJobProgressParser

Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_attempts = 3
Delayed::Worker.sleep_delay = 1

Delayed::Job.class_eval do
  attr_accessor :async_outcome_remembered

  after_create :remember_queued_async_job
  before_destroy :remember_killed_async_job

  def remember_queued_async_job
    payload = payload_object
    payload.remember_async_job!(self, 'queued') if payload.respond_to?(:remember_async_job!)
  rescue Delayed::DeserializationError
    nil
  end

  def remember_killed_async_job
    Job.remember_killed!(self)
  end
end

Delayed::Worker.class_eval do
  alias_method :run_was, :run
  def run(job)
    Customer.transaction isolation: :read_committed do
      run_was job
    end
  end
end
