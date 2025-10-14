require 'test_helper'

class ParseIdsRefsTest < ActiveSupport::TestCase
  setup do
    @tag_one = tags(:tag_one)
    @tag_two = tags(:tag_two)
  end

  test 'where with ids list returns matching tags' do
    ids_array = CoerceArrayString.parse(@tag_one.id.to_s + ',' + @tag_two.id.to_s)
    condition = ParseIdsRefs.where(Tag, ids_array)

    result = Tag.where(condition).to_a
    assert_includes result, @tag_one
    assert_includes result, @tag_two
  end

  test 'where with mixed ids and refs returns matching tags' do
    mixed_array = CoerceArrayString.parse([@tag_one.id.to_s, "ref:#{@tag_two.ref}"].join(','))
    condition = ParseIdsRefs.where(Tag, mixed_array)

    result = Tag.where(condition).to_a
    assert_includes result, @tag_one
    assert_includes result, @tag_two
  end

  test 'where_pluck_ids returns only ids' do
    ids_array = CoerceArrayString.parse(@tag_one.id.to_s + ',' + @tag_two.id.to_s)
    result_ids = ParseIdsRefs.where_pluck_ids(Tag, ids_array)

    assert_includes result_ids, @tag_one.id
    assert_includes result_ids, @tag_two.id
    assert_equal 2, result_ids.length
  end

  test 'where_pluck_refs returns only refs' do
    refs_array = CoerceArrayString.parse("ref:#{@tag_one.ref},ref:#{@tag_two.ref}")
    result_refs = ParseIdsRefs.where_pluck_refs(Tag, refs_array)

    assert_includes result_refs, @tag_two.ref
    assert_equal 1, result_refs.length
  end

  test 'where_pluck_ids with mixed ids and refs returns only ids' do
    mixed_array = CoerceArrayString.parse([@tag_one.id.to_s, "ref:#{@tag_two.ref}"].join(','))
    result_ids = ParseIdsRefs.where_pluck_ids(Tag, mixed_array)

    assert_includes result_ids, @tag_one.id
    assert_includes result_ids, @tag_two.id
    assert_equal 2, result_ids.length
  end

  test 'where_pluck_refs with mixed ids and refs returns only refs' do
    mixed_array = CoerceArrayString.parse([@tag_one.id.to_s, "ref:#{@tag_two.ref}"].join(','))
    result_refs = ParseIdsRefs.where_pluck_refs(Tag, mixed_array)

    assert_includes result_refs, @tag_two.ref
    assert_equal 1, result_refs.length
  end

  test 'where with case insensitive ref search' do
    # Test with uppercase ref
    uppercase_ref_array = CoerceArrayString.parse("ref:#{@tag_one.ref.upcase}")
    condition = ParseIdsRefs.where(Tag, uppercase_ref_array)
    result = Tag.where(condition).to_a

    assert_includes result, @tag_one
    assert_equal 1, result.length
  end

  test 'where_pluck_refs with case insensitive ref search' do
    # Test with mixed case refs
    @tag_one.update(ref: 'MixedCase')
    mixed_case_array = CoerceArrayString.parse("ref:#{@tag_one.ref.upcase},ref:#{@tag_two.ref.downcase}")
    result_refs = ParseIdsRefs.where_pluck_refs(Tag, mixed_case_array)

    assert_includes result_refs, @tag_one.ref
    assert_includes result_refs, @tag_two.ref
    assert_equal 2, result_refs.length
  end

  test 'where with customer restriction' do
    customer_one = customers(:customer_one)
    customer_two = customers(:customer_two)

    # Create tags for different customers
    tag_customer_one = customer_one.tags.create!(label: 'Customer One Tag', ref: 'cust1')
    tag_customer_two = customer_two.tags.create!(label: 'Customer Two Tag', ref: 'cust2')

    # Search without customer restriction should find both
    condition_no_customer = ParseIdsRefs.where(Tag, ['ref:cust1', 'ref:cust2'])
    result_no_customer = Tag.where(condition_no_customer).to_a
    assert_equal 2, result_no_customer.length

    # Search with customer_one restriction should find only customer_one tags
    condition_with_customer = ParseIdsRefs.where(Tag, ['ref:cust1', 'ref:cust2'], customer: customer_one)
    result_with_customer = Tag.where(condition_with_customer).to_a
    assert_equal 1, result_with_customer.length
    assert_includes result_with_customer, tag_customer_one
    assert_not_includes result_with_customer, tag_customer_two
  end
end
