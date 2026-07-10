# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionFailureArtifactsTest < ActiveSupport::TestCase
  setup do
    @name = 'foundation-default'
    @basename = 'foundation-default'
    @snapshots_dir = Rails.root.join('visual-regression/tests/lookbook.vrt.spec.ts-snapshots')
    @test_results_dir = Rails.root.join('visual-regression/test-results')
    @snapshot_path = @snapshots_dir.join("#{@basename}-linux.png")
    @failure_dir = @test_results_dir.join('lookbook.vrt-lookbook-foundation-default')
    @actual_path = @failure_dir.join("#{@basename}-actual.png")

    FileUtils.mkdir_p(@snapshots_dir)
    FileUtils.mkdir_p(@failure_dir)
    File.write(@snapshot_path, 'baseline-bytes')
    File.write(@actual_path, 'different-bytes')
  end

  teardown do
    FileUtils.rm_rf(@test_results_dir)
    FileUtils.rm_rf(@snapshots_dir)
  end

  test 'failed? is true when actual bytes differ from snapshot' do
    assert Lookbook::VisualRegression::FailureArtifacts.failed?(@name)
  end

  test 'failed? is false when actual bytes match snapshot' do
    File.write(@actual_path, 'baseline-bytes')

    assert_not Lookbook::VisualRegression::FailureArtifacts.failed?(@name)
  end

  test 'clear! removes playwright failure pngs for preview' do
    Lookbook::VisualRegression::FailureArtifacts.clear!(@name)

    assert_not @actual_path.exist?
  end
end
