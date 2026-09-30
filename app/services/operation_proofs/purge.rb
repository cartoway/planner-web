# frozen_string_literal: true

module OperationProofs
  # Purge ActiveStorage photos/signatures on OperationStop past customer retention.
  # Retention is anchored on operations.date (business day), not blob upload time.
  class Purge
    DEFAULT_RETENTION_DAYS = 365
    MIN_RETENTION_DAYS = 30
    MAX_RETENTION_DAYS = 1825 # 5 years
    ATTACHMENT_NAMES = %w[photos signature].freeze

    def self.call
      new.call
    end

    def call
      deleted = 0
      Customer.find_each do |customer|
        deleted += purge_customer(customer)
      end
      deleted
    end

    private

    def purge_customer(customer)
      days = (customer.proof_retention_days.presence || DEFAULT_RETENTION_DAYS).to_i
      days = days.clamp(MIN_RETENTION_DAYS, MAX_RETENTION_DAYS)
      cutoff = days.days.ago.to_date

      stop_ids = OperationStop
                 .joins(operation_route: :operation)
                 .where(operations: { customer_id: customer.id })
                 .where('operations.date < ?', cutoff)
                 .pluck(:id)
      return 0 if stop_ids.empty?

      deleted = 0
      ActiveStorage::Attachment
        .where(record_type: 'OperationStop', record_id: stop_ids, name: ATTACHMENT_NAMES)
        .find_each do |attachment|
          attachment.purge
          deleted += 1
        end
      deleted
    end
  end
end
