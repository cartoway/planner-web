# frozen_string_literal: true

class OperationStopStatusEvent < ApplicationRecord
  SOURCES = %w[mobile fleet api device system import backoffice].freeze

  belongs_to :operation_stop

  validates :recorded_at, :source, presence: true
  validates :source, inclusion: { in: SOURCES }

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  def set_creation_date
    self.created_at ||= Time.current
  end
end
