class DelayedJobManager
  class << self
    def enqueue_with_delay(job_class, *args, delay_seconds: 30)
      return unless Planner::Application.config.delayed_job_use

      job = job_class.new(*args)

      job_signature = build_job_signature(job_class, *args)

      existing_job = Delayed::Job.where(
        "handler LIKE ? AND handler LIKE ?",
        "%#{job_class.name}%",
        "%#{job_signature}%"
      ).first

      if existing_job
        existing_job.update_column(:run_at, delay_seconds.seconds.from_now)
        existing_job
      else
        Delayed::Job.enqueue(job, run_at: delay_seconds.seconds.from_now)
      end
    end

    def enqueue_simplify_geojson_tracks_job(customer_id, route_id, delay_seconds: 30)
      enqueue_with_delay(SimplifyGeojsonTracksJob, customer_id, route_id, delay_seconds: delay_seconds)
    end

    private

    def build_job_signature(job_class, *args)
      if job_class == SimplifyGeojsonTracksJob
        customer_id, route_id = args
        "customer_id: #{customer_id}\nroute_id: #{route_id}"
      else
        args.join(' ')
      end
    end
  end
end
