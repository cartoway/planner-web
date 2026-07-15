# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionAcceptSnapshotTest < ActiveSupport::TestCase
  setup do
    @previous_vrt = ENV.fetch('LOOKBOOK_VRT', nil)
    ENV['LOOKBOOK_VRT'] = '1'

    @name = 'foundation-default'
    @tmp_snapshots = Pathname.new(Dir.mktmpdir('lookbook-snapshots-'))
    @original_snapshots_dir = Lookbook::VisualRegression::AcceptSnapshot::SNAPSHOTS_DIR
    Lookbook::VisualRegression::AcceptSnapshot.send(:remove_const, :SNAPSHOTS_DIR)
    Lookbook::VisualRegression::AcceptSnapshot.const_set(:SNAPSHOTS_DIR, @tmp_snapshots)

    @public_dir = Rails.root.join('public/lookbook-visual-regression', @name)
    @snapshot_path = @tmp_snapshots.join("#{@name}-linux.png")
    @actual_path = @public_dir.join('actual.png')

    FileUtils.mkdir_p(@public_dir)
    File.write(@actual_path, 'new-actual-image')
    File.write(@snapshot_path, 'old-baseline')
  end

  teardown do
    ENV['LOOKBOOK_VRT'] = @previous_vrt
    FileUtils.rm_rf(Rails.root.join('public/lookbook-visual-regression'))
    Lookbook::VisualRegression::AcceptSnapshot.send(:remove_const, :SNAPSHOTS_DIR)
    Lookbook::VisualRegression::AcceptSnapshot.const_set(:SNAPSHOTS_DIR, @original_snapshots_dir)
    FileUtils.rm_rf(@tmp_snapshots) if @tmp_snapshots
  end

  test 'call! copies actual png to linux snapshot baseline' do
    actual_bytes = File.binread(@actual_path)
    Lookbook::VisualRegression::AcceptSnapshot.call!(@name, refresh_report: false)

    assert_equal actual_bytes, File.binread(@snapshot_path)
  end

  test 'call! clears playwright failure artifacts for preview' do
    failure_dir = Rails.root.join('visual-regression/test-results/lookbook.vrt-lookbook-foundation-default')
    FileUtils.mkdir_p(failure_dir)
    failure_actual = failure_dir.join('foundation-default-actual.png')
    File.write(failure_actual, 'playwright-actual')

    Lookbook::VisualRegression::AcceptSnapshot.call!(@name, refresh_report: false)

    assert_not failure_actual.exist?
  end

  test 'call! raises when visual regression is disabled' do
    ENV['LOOKBOOK_VRT'] = '0'

    assert_raises(Lookbook::VisualRegression::AcceptSnapshot::Error) do
      Lookbook::VisualRegression::AcceptSnapshot.call!(@name, refresh_report: false)
    end
  end

  test 'call! raises when actual screenshot is missing' do
    FileUtils.rm_f(@actual_path)

    assert_raises(Lookbook::VisualRegression::AcceptSnapshot::Error) do
      Lookbook::VisualRegression::AcceptSnapshot.call!(@name, refresh_report: false)
    end
  end

  test 'call! raises for unknown preview name' do
    assert_raises(Lookbook::VisualRegression::AcceptSnapshot::Error) do
      Lookbook::VisualRegression::AcceptSnapshot.call!('not-a-real-preview', refresh_report: false)
    end
  end
end
