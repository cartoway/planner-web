# frozen_string_literal: true

require 'test_helper'

class PreloadersBatchAssociationPreloadTest < ActiveSupport::TestCase
  test 'preload! does nothing for blank records' do
    assert_nothing_raised do
      Preloaders::BatchAssociationPreload.preload!([], [])
      Preloaders::BatchAssociationPreload.preload!(nil, [])
    end
  end
end
