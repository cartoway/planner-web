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
      "<input type=\"number\" name=\"custom_attribute[default_value]\" id=\"custom_attribute_default_value\" value=\"5\" stop=\"1\" class=\"form-control\" onkeypress=\"return event.charCode &gt;= 48 &amp;&amp; event.charCode &lt;= 57\" />",
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

  test 'mobile_custom_attributes_for returns all stop visit custom attributes' do
    customer = customers(:customer_one)
    stop = stops(:stop_one_one)

    result = mobile_custom_attributes_for(customer, stop)

    assert_includes result, custom_attributes(:custom_attribute_stop_one)
    assert_includes result, custom_attributes(:custom_attribute_stop_two)
  end

  test 'mobile_visit_custom_attributes_for returns only visible visit custom attributes' do
    customer = customers(:customer_one)

    result = mobile_visit_custom_attributes_for(customer)

    assert_includes result, custom_attributes(:custom_attribute_visit_visible)
    refute_includes result, custom_attributes(:custom_attribute_visit_hidden)
  end

  test 'mobile_vehicle_custom_attributes_for returns only visible vehicle custom attributes' do
    customer = customers(:customer_one)

    result = mobile_vehicle_custom_attributes_for(customer)

    assert_includes result, custom_attributes(:custom_attribute_one)
    refute_includes result, custom_attributes(:custom_attribute_vehicle_hidden)
  end

  test 'mobile_route_custom_attributes_for returns only visible route custom attributes without related field' do
    customer = customers(:customer_one)

    result = mobile_route_custom_attributes_for(customer)

    assert_includes result, custom_attributes(:custom_attribute_route_visible)
    refute_includes result, custom_attributes(:custom_attribute_route_hidden)
  end

  test 'custom_attribute_mobile_visible_configurable? requires cartoway deliver and mobile eligible object class' do
    customer = customers(:customer_one)
    customer.update!(devices: { deliver: { enable: true } })

    assert custom_attribute_mobile_visible_configurable?(customer, 'visit')
    refute custom_attribute_mobile_visible_configurable?(customer, 'stop_visit')

    customer.update!(devices: {})
    refute custom_attribute_mobile_visible_configurable?(customer, 'visit')
  end
end
