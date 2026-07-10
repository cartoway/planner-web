# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionControllerTest < ActionController::TestCase
  tests Lookbook::VisualRegressionController

  setup do
    @previous_vrt = ENV.fetch('LOOKBOOK_VRT', nil)
    ENV['LOOKBOOK_VRT'] = '1'

    @name = 'foundation-default'
    @snapshots_dir = Rails.root.join('visual-regression/tests/lookbook.vrt.spec.ts-snapshots')
    @public_dir = Rails.root.join('public/lookbook-visual-regression', @name)
    @snapshot_path = @snapshots_dir.join("#{@name}-linux.png")
    @actual_path = @public_dir.join('actual.png')

    FileUtils.mkdir_p(@public_dir)
    FileUtils.mkdir_p(@snapshots_dir)
    File.write(@actual_path, 'new-actual-image')
    File.write(@snapshot_path, 'old-baseline')
  end

  teardown do
    ENV['LOOKBOOK_VRT'] = @previous_vrt
    FileUtils.rm_rf(Rails.root.join('public/lookbook-visual-regression'))
  end

  test 'accept returns forbidden when LOOKBOOK_VRT is disabled' do
    ENV['LOOKBOOK_VRT'] = '0'

    post :accept, params: { name: @name }, as: :json

    assert_response :forbidden
    assert_equal false, JSON.parse(response.body)['ok']
  end

  test 'accept copies baseline and returns success' do
    expected_bytes = File.binread(@actual_path)

    Lookbook::VisualRegression::AcceptSnapshot.stub(:refresh_report!, true) do
      post :accept, params: { name: @name }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body['ok']
    assert_equal @name, body['name']
    assert_equal expected_bytes, File.binread(@snapshot_path)
  end
end
