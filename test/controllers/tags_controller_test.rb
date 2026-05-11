require 'test_helper'

class TagsControllerTest < ActionController::TestCase

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @tag = tags(:tag_one)
    sign_in users(:user_one)
    assert_valid response
  end

  teardown do
    u = users(:user_one)
    u.update!(role_id: nil) if u.reload.role_id.present?
  end

  test 'user can only view tags from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @tag
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @tag

    get :edit, params: { id: tags(:tag_three) }
    assert_response :not_found
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:tags)
    assert_valid response
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create tag' do
    assert_difference('Tag.count') do
      post :create, params: { tag: { label: 'label' } }
    end

    assert_redirected_to tags_path
  end

  test 'should not create tag' do
    assert_difference('Tag.count', 0) do
      post :create, params: { tag: { label: '' } }
    end

    assert_template :new
    tag = assigns(:tag)
    assert tag.errors.any?
    assert_valid response
  end

  test 'should get edit' do
    get :edit, params: { id: @tag }
    assert_response :success
    assert_valid response
  end

  test 'should update tag' do
    patch :update, params: { id: @tag, tag: { label: @tag.label } }
    assert_redirected_to tags_path
  end

  test 'should not update tag' do
    patch :update, params: { id: @tag, tag: { label: '' } }
    assert_template :edit
    tag = assigns(:tag)
    assert tag.errors.any?
    assert_valid response
  end

  test 'should destroy tag' do
    assert_difference('Tag.count', -1) do
      delete :destroy, params: { id: @tag }
    end

    assert_redirected_to tags_path
  end

  test 'should destroy multiple tag' do
    assert_difference('Tag.count', -2) do
      delete :destroy_multiple, params: { tags: { tags(:tag_one).id => 1, tags(:tag_two).id => 1 } }
    end

    assert_redirected_to tags_path
  end

  test 'index redirects when tags form is hidden' do
    u = users(:user_one)
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['tags'] = { 'visible' => false, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "hidden-tags-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
    )
    u.update!(role_id: role.id)
    sign_in u

    get :index
    assert_response :redirect
    assert_redirected_to root_url
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end

  test 'create redirects when tags form is read-only' do
    u = users(:user_one)
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['tags'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "ro-tags-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
    )
    u.update!(role_id: role.id)
    sign_in u

    assert_no_difference('Tag.count') do
      post :create, params: { tag: { label: 'from restricted role' } }
    end
    assert_response :redirect
    assert_redirected_to root_url
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end

  test 'destroy_multiple is forbidden when tags form is read-only' do
    u = users(:user_one)
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['tags'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "ro-tags-destroy-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
    )
    u.update!(role_id: role.id)
    sign_in u

    assert_no_difference('Tag.count') do
      delete :destroy_multiple, params: { tags: { tags(:tag_one).id => 1, tags(:tag_two).id => 1 } }
    end
    assert_response :forbidden
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end
end
