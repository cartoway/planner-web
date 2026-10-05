# frozen_string_literal: true

DeliverDemoJobStruct = Job.new(:operation_id, :cursors) unless defined?(DeliverDemoJobStruct)
class DeliverDemoJob < DeliverDemoJobStruct
  def perform
    operation = Operation.find_by(id: operation_id)
    return if operation.nil?
    return clear_job!(operation) unless operation.open? && DeliverDemo.enabled?(operation.customer)

    next_cursors, done = DeliverDemo::Tick.call(operation: operation, cursors: cursors || {})
    return clear_job!(operation) if done

    delayed = Delayed::Job.enqueue(
      DeliverDemoJob.new(operation_id, next_cursors),
      run_at: DeliverDemo::DELAY.from_now
    )
    operation.update_column(:demo_job_id, delayed.id)
  end

  private

  def clear_job!(operation)
    operation.update_column(:demo_job_id, nil) if operation.demo_job_id.present?
  end
end
