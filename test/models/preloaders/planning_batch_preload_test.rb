# frozen_string_literal: true

require 'test_helper'

class PreloadersPlanningBatchPreloadTest < ActiveSupport::TestCase
  test 'preload! does nothing for blank records' do
    assert_nothing_raised do
      Preloaders::PlanningBatchPreload.preload!([])
      Preloaders::PlanningBatchPreload.preload!(nil)
    end
  end

  test 'ASSOCIATIONS is frozen and includes planning tags' do
    assert Preloaders::PlanningBatchPreload::ASSOCIATIONS.frozen?
    assert_includes Preloaders::PlanningBatchPreload::ASSOCIATIONS, :tags
  end

  test 'each_batch does not log ignored-order warning for default-scoped Planning' do
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    old_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = logger
    begin
      Preloaders::PlanningBatchPreload.each_batch(Planning.where(id: -1), batch_size: 30) do |_batch|
        :noop
      end
    ensure
      ActiveRecord::Base.logger = old_logger
    end
    refute_includes io.string, ActiveRecord::Batches::ORDER_IGNORE_MESSAGE
  end
end
