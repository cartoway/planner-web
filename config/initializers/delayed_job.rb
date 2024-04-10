Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_attempts = 3
Delayed::Worker.sleep_delay = 1
Delayed::Worker.logger = Logger.new('delayed_job_logs')

Delayed::Worker.class_eval do
  alias_method :run_was, :run
  def run(job)
    Customer.transaction isolation: :read_committed do
      run_was job
    end
  end
end

module Delayed::WorkerClassReloadingPatch
  # Override Delayed::Worker#reserve_job to optionally reload classes before running a job
  def reserve_job(*)
    job = super

    if job && self.class.reload_app?
      ActionDispatch::Reloader.cleanup!
      ActionDispatch::Reloader.prepare!
    end

    job
  end

  # Override Delayed::Worker#reload! which is called from the job polling loop to not reload classes
  def reload!
    # no-op
  end
end
Delayed::Worker.send(:prepend, Delayed::WorkerClassReloadingPatch)
