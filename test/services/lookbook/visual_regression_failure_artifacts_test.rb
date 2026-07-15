# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionFailureArtifactsTest < ActiveSupport::TestCase
  setup do
    @name = 'foundation-default'
    @basename = 'foundation-default'
    @tmp_snapshots = Pathname.new(Dir.mktmpdir('lookbook-snapshots-'))
    @tmp_test_results = Pathname.new(Dir.mktmpdir('lookbook-test-results-'))
    Lookbook::VisualRegression::FailureArtifacts.stubs(:snapshots_dir).returns(@tmp_snapshots)
    Lookbook::VisualRegression::FailureArtifacts.stubs(:test_results_dir).returns(@tmp_test_results)

    @snapshot_path = @tmp_snapshots.join("#{@basename}-linux.png")
    @failure_dir = @tmp_test_results.join('lookbook.vrt-lookbook-foundation-default')
    @actual_path = @failure_dir.join("#{@basename}-actual.png")

    FileUtils.mkdir_p(@failure_dir)
    File.write(@snapshot_path, 'baseline-bytes')
    File.write(@actual_path, 'different-bytes')
  end

  teardown do
    Lookbook::VisualRegression::FailureArtifacts.unstub(:snapshots_dir)
    Lookbook::VisualRegression::FailureArtifacts.unstub(:test_results_dir)
    FileUtils.rm_rf(@tmp_snapshots) if @tmp_snapshots
    FileUtils.rm_rf(@tmp_test_results) if @tmp_test_results
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
