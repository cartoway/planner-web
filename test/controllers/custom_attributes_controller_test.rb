require 'test_helper'

class CustomAttributesControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_one)
    @custom_attribute = custom_attributes(:custom_attribute_one)
  end

  test 'should get edit' do
    sign_in users(:user_one)
    get :edit, params: { id: @custom_attribute }
    assert_response :success
    assert_valid response
  end

  test 'reset_mobile_visible_partial renders field only for eligible object classes' do
    users(:user_one).customer.update!(devices: { deliver: { enable: true } })

    post :reset_mobile_visible_partial, params: {
      custom_attribute: { object_class_with_related_field: 'visit' }
    }, format: :js

    assert_response :success
    assert_includes response.body, 'custom_attribute_mobile_visible'
    assert_equal false, assigns(:mobile_visible)

    post :reset_mobile_visible_partial, params: {
      custom_attribute: { object_class_with_related_field: 'stop_visit' }
    }, format: :js

    assert_response :success
    refute_includes response.body, 'custom_attribute_mobile_visible'
  end

  test 'reset_mobile_visible_partial hides field when cartoway deliver is disabled' do
    users(:user_one).customer.update!(devices: {})

    post :reset_mobile_visible_partial, params: {
      custom_attribute: { object_class_with_related_field: 'visit' }
    }, format: :js

    assert_response :success
    refute_includes response.body, 'custom_attribute_mobile_visible'
  end

  test 'should ignore mobile_visible when object class is not mobile eligible' do
    patch :update, params: {
      id: @custom_attribute,
      custom_attribute: {
        name: @custom_attribute.name,
        object_type: 'boolean',
        object_class: 'stop_visit',
        object_class_with_related_field: 'stop_visit',
        default_value: false,
        mobile_visible: false
      }
    }

    assert_redirected_to custom_attributes_path
    assert @custom_attribute.reload.mobile_visible
  end

  test 'should update custom_attributes' do
    sign_in users(:user_one)
    patch :update, params: { id: @custom_attribute, custom_attribute: { name: 'foo', object_type: 'boolean', object_class: 'stop_visit', default_value: false }}
    assert_redirected_to custom_attributes_path
    assert_equal 'description one', @custom_attribute.reload['description']
    assert_equal 'foo', @custom_attribute.reload['name']
    assert_equal 'boolean', @custom_attribute.reload['object_type']
    assert_equal 'stop_visit', @custom_attribute.reload['object_class']
    assert_equal '0', @custom_attribute.reload['default_value']
  end

  test 'should delete custom_attribute' do
    assert_difference('CustomAttribute.count', -1) do
      delete :destroy, params: { id: @custom_attribute }
    end
    assert_redirected_to custom_attributes_path
  end

  test 'should delete multiple custom_attributes' do
    assert_difference('CustomAttribute.count', -2) do
      delete :destroy_multiple, params: { custom_attributes: { custom_attributes(:custom_attribute_one).id => 1, custom_attributes(:custom_attribute_two).id => 1 }}
    end
    assert_redirected_to custom_attributes_path
  end

  test 'create is forbidden when custom_attributes form is read-only' do
    u = users(:user_one)
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['custom_attributes'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "ro-custom-attributes-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
    )
    u.update!(role_id: role.id)
    sign_in u

    assert_no_difference('CustomAttribute.count') do
      post :create, params: {
        custom_attribute: {
          name: 'blocked',
          object_type: 'boolean',
          object_class: 'stop_visit',
          default_value: false
        }
      }
    end
    assert_response :forbidden
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end
end
