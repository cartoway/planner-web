require 'delayed_job_progress_parser'

Delayed::Job.include DelayedJobProgressParser

Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_attempts = 3
Delayed::Worker.sleep_delay = 1
