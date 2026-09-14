class V01::Entities::Job < Grape::Entity
  def self.entity_name
    'V01_Job'
  end

  expose(:message, documentation: { type: String, desc: 'Optional status message (for example when the job is in transmission).' }, if: lambda { |_m, options| options[:message] }) { |_m, options|
    options[:message]
  }
  expose(:id, documentation: { type: Integer, desc: 'Delayed job id. Poll GET /jobs/:id until status is succeeded, failed, or killed.', example: 88 })
  expose(:status, documentation: { type: String, values: %w[running queued working failed succeeded killed], desc: 'running while the Delayed::Job row exists without failed_at; queued/working from last_async_jobs while in progress; succeeded, failed, or killed after completion.' }) { |m|
    if m.respond_to?(:failed_at)
      m.failed_at ? 'failed' : 'running'
    else
      m.status
    end
  }
  expose(:type, documentation: { type: String, desc: 'Job kind derived from the class name: optimizer, geocoder, geocoder_stores.', example: 'optimizer' }) { |m|
    if m.respond_to?(:name)
      m.name.to_s.underscore.parameterize(separator: '_').gsub(/_job$/, '')
    else
      m.type
    end
  }
  expose(:attempts, documentation: { type: Integer, desc: 'Number of execution attempts.', example: 1 }, if: lambda { |m, _| m.respond_to?(:attempts) })
  expose(:created_at, documentation: { type: Date, desc: 'When the job was enqueued.' }, if: lambda { |m, _| m.respond_to?(:created_at) })
  expose(:failed_at, documentation: { type: Date, desc: 'Set when the job failed. Null while running or after success.' }, if: lambda { |m, _| m.respond_to?(:failed_at) })
  expose(:locked_at, documentation: { type: Date, desc: 'Set while a worker is executing the job.' }, if: lambda { |m, _| m.respond_to?(:locked_at) })
  expose(:progress, documentation: { type: JSON, desc: 'Optimizer/geocoder progress payload (percent, phase, nested job_id). Shape depends on job type.' }, if: lambda { |m, _| m.respond_to?(:progress) })
  expose(:run_at, documentation: { type: Date, desc: 'Scheduled run time.' }, if: lambda { |m, _| m.respond_to?(:run_at) })
  expose(:finished_at, documentation: { type: DateTime, desc: 'Set when status is succeeded.' }, if: lambda { |m, _| m.respond_to?(:finished_at) && m.finished_at })
end
