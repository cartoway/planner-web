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

  test 'should update custom_attributes' do
    sign_in users(:user_one)
    patch :update, params: { id: @custom_attribute, custom_attribute: { name: 'foo', object_type: 'boolean', object_class: 'stop', default_value: false }}
    assert_redirected_to custom_attributes_path
    assert_equal 'description one', @custom_attribute.reload['description']
    assert_equal 'foo', @custom_attribute.reload['name']
    assert_equal 'boolean', @custom_attribute.reload['object_type']
    assert_equal 'stop', @custom_attribute.reload['object_class']
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
end
