# frozen_string_literal: true

require 'test_helper'

class ApplicationStylesheetManifestTest < ActiveSupport::TestCase
  test 'application manifest excludes v2 and lookbook entry stylesheets' do
    manifest = Rails.root.join('app/assets/stylesheets/application.css.scss').read

    refute_match(%r{\*= require_tree \.(?!/api_web)}, manifest)
    refute_match(%r{require\s+v2/application}, manifest)
    refute_match(/require\s+lookbook_preview/, manifest)
  end

  # Goes through Sprockets (incl. optional CSS compressor). LibSass compression
  # rejects modern min()/calc() with mixed rem/vw — compressor must stay off.
  test 'v2 application is served by Sprockets with mixed CSS units' do
    asset = Rails.application.assets.find_asset('v2/application')

    assert asset, 'expected v2/application asset'
    assert_match(/min\(\s*22rem/, asset.to_s)
  end

  test 'lookbook preview stylesheets are in the Sprockets precompile list' do
    list = Rails.application.config.assets.precompile

    assert_includes list, 'v2/layout_bootstrap_overrides.css'
    assert_includes list, 'lookbook_preview.css'
  end
end

class V2LayoutHeadTest < ActiveSupport::TestCase
  test 'v2 head does not load v1 application.css' do
    head = Rails.root.join('app/views/v2/layouts/_head.html.haml').read

    refute_match(/stylesheet_link_tag\s+['"]application['"]/, head)
  end

  test 'v2 application styles include menu-left label ellipsis' do
    styles = Rails.root.join('app/assets/stylesheets/v2/application.scss').read

    assert_includes styles, 'text-overflow: ellipsis'
    assert_includes styles, '.hidden-menu.menu_label'
    assert_includes styles, '.dropdown .menu_label'
  end

  test 'v2 application imports v2 scaffolds instead of v1 scaffolds' do
    styles = Rails.root.join('app/assets/stylesheets/v2/application.scss').read

    refute_match(/@import\s+["']scaffolds["']/, styles)
    assert_match(%r{@import\s+["']v2/scaffolds["']}, styles)
  end

  test 'v2 scaffolds enable mobile topbar menu for all cartoway-v2 pages' do
    scaffolds = Rails.root.join('app/assets/stylesheets/v2/_scaffolds.scss').read

    assert_includes scaffolds, 'body.cartoway-v2'
    assert_includes scaffolds, '.menu-mobile-topbar'
    assert_includes scaffolds, 'is-mobile-open'
    assert_includes scaffolds, '--menu-mobile-topbar-height'
  end
end
