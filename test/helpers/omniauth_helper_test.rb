require 'test_helper'

class OmniauthHelperTest < ActionView::TestCase
  include OmniauthHelper

  test "provider_logo_path returns correct path for entra_id" do
    # Create the logo file if it doesn't exist
    logo_dir = Rails.root.join('app', 'assets', 'images', 'sso')
    FileUtils.mkdir_p(logo_dir)
    logo_file = logo_dir.join('microsoft.svg')
    FileUtils.touch(logo_file) unless File.exist?(logo_file)

    path = provider_logo_path(:entra_id)
    assert_equal 'sso/microsoft.svg', path
  end

  test "provider_logo_path returns nil for unknown provider" do
    path = provider_logo_path(:unknown_provider)
    assert_nil path
  end

  test "provider_icon_class returns correct icon for entra_id" do
    icon_class = provider_icon_class(:entra_id)
    assert_equal 'fa fa-windows', icon_class
  end

  test "provider_icon_class returns fallback for unknown provider" do
    icon_class = provider_icon_class(:unknown_provider)
    assert_equal 'fa fa-sign-in', icon_class
  end

  test "omniauth_provider_logo returns image tag when logo exists" do
    # Create the logo file
    logo_dir = Rails.root.join('app', 'assets', 'images', 'sso')
    FileUtils.mkdir_p(logo_dir)
    logo_file = logo_dir.join('microsoft.svg')
    FileUtils.touch(logo_file) unless File.exist?(logo_file)

    result = omniauth_provider_logo(:entra_id, height: 20)
    assert_match(/<img/, result)
    assert_match(%r{sso/microsoft\.svg}, result)
  end

  test "omniauth_provider_logo returns icon fallback when logo doesn't exist" do
    # Ensure logo doesn't exist
    logo_file = Rails.root.join('app', 'assets', 'images', 'sso', 'nonexistent.svg')
    FileUtils.rm_f(logo_file)

    # Mock provider_logo_path to return nil
    self.stubs(:provider_logo_path).returns(nil)

    result = omniauth_provider_logo(:nonexistent)
    assert_match(/<i/, result)
    assert_match(/fa fa-sign-in/, result)
  end
end
