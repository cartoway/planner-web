# frozen_string_literal: true

# Persists a planning state snapshot that was already built in the request.
# Keeps undo correct: payload/statistics are frozen at enqueue time.
# Payload is zlib+Base64 so delayed_jobs.handler stays small (large plans).
# Not in Job::ASYNC_KINDS — capture must not drive last_async_jobs / UI progress.
unless defined?(PlanningStateCaptureJobStruct)
  PlanningStateCaptureJobStruct = Job.new(
    :planning_id, :captured_at, :trigger, :category, :payload, :statistics
  )
end
class PlanningStateCaptureJob < PlanningStateCaptureJobStruct
  def self.compress_payload(payload)
    Base64.strict_encode64(Zlib::Deflate.deflate(JSON.generate(payload)))
  end

  def self.decompress_payload(payload)
    JSON.parse(Zlib::Inflate.inflate(Base64.strict_decode64(payload)))
  end

  def perform
    planning = Planning.find_by(id: planning_id)
    return unless planning

    PlanningState.create!(
      planning_id: planning_id,
      captured_at: captured_at,
      trigger: trigger,
      category: category,
      payload: self.class.decompress_payload(payload),
      statistics: statistics
    )
    PlanningState.prune_excess!(planning_id)
  end
end
