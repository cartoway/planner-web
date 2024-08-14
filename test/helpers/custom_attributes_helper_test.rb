require 'test_helper'

class CustomAttributesHelperTest < ActionView::TestCase

  test 'test render typed value boolean' do
    object_type = 'boolean'
    typed_default_value = true
    custom_attribute_default_value_form_field(object_type, typed_default_value)
    assert_template "shared/_check_box"
  end

  test 'test render typed value string' do
    object_type = 'string'
    typed_default_value = 'Ok'
    assert_equal(
      "<textarea name=\"custom_attribute[default_value]\" id=\"custom_attribute_default_value\" class=\"form-control\">\nOk</textarea>",
      custom_attribute_default_value_form_field(object_type, typed_default_value)
    )
  end

  test 'test render typed value integer' do
    object_type = 'integer'
    typed_default_value = 5
    assert_equal(
      "<input type=\"number\" name=\"custom_attribute[default_value]\" id=\"custom_attribute_default_value\" value=\"5\" class=\"form-control\" />",
      custom_attribute_default_value_form_field(object_type, typed_default_value)
    )
  end

  test 'test render typed value float' do
    object_type = 'float'
    typed_default_value = 6.0
    assert_equal(
      "<input type=\"number\" name=\"custom_attribute[default_value]\" id=\"custom_attribute_default_value\" value=\"6.0\" step=\"any\" class=\"form-control\" />",
      custom_attribute_default_value_form_field(object_type, typed_default_value)
    )
  end

  test 'test array to object_type' do
    object_type = 'boolean'
    raw_default_value = ['hello'].to_json
    assert_equal true, object_type_cast(object_type, raw_default_value)

    object_type = 'string'
    assert_equal 'hello', object_type_cast(object_type, raw_default_value)

    object_type = 'integer'
    assert_equal 0, object_type_cast(object_type, raw_default_value)

    object_type = 'float'
    assert_equal 0.0, object_type_cast(object_type, raw_default_value)
  end
end
