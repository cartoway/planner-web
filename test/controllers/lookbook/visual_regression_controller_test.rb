# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionControllerTest < ActionController::TestCase
  tests Lookbook::VisualRegressionController

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
