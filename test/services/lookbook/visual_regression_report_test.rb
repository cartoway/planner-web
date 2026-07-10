# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionReportTest < ActiveSupport::TestCase
  setup do
    @public_dir = Rails.root.join('public/lookbook-visual-regression')
    @manifest_path = @public_dir.join('manifest.json')
    FileUtils.rm_rf(@public_dir)
  end

  test 'load returns nil when manifest is missing' do
    assert_nil Lookbook::VisualRegression::Report.load
    assert_not Lookbook::VisualRegression::Report.available?
  end

  test 'load reads manifest and preview rows' do
    FileUtils.mkdir_p(@public_dir)
    @manifest_path.write(
      {
        generated_at: '2026-07-09T12:00:00Z',
        status: 'failed',
        passed_count: 1,
        failed_count: 1,
        previews: [
          {
            name: 'foundation-default',
            path: 'design_system/foundation/default',
            status: 'failed',
            expected_url: '/lookbook-visual-regression/foundation-default/expected.png',
            actual_url: '/lookbook-visual-regression/foundation-default/actual.png',
            diff_url: '/lookbook-visual-regression/foundation-default/diff.png',
            lookbook_preview_url: '/lookbook/preview/design_system/foundation/default'
          }
        ]
      }.to_json
    )

    report = Lookbook::VisualRegression::Report.load

    assert_not report.passed?
    assert_equal 1, report.failed_count
    assert_equal 'foundation-default', report.failed_previews.first.name
  end
end
