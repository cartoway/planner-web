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
    assert_equal 2, result_ids.size
  end

  test 'where_pluck_refs returns only refs' do
    refs_array = CoerceArrayString.parse("ref:#{@tag_one.ref},ref:#{@tag_two.ref}")
    result_refs = ParseIdsRefs.where_pluck_refs(Tag, refs_array)

    assert_includes result_refs, @tag_two.ref
    assert_equal 1, result_refs.size
  end

  test 'where_pluck_ids with mixed ids and refs returns only ids' do
    mixed_array = CoerceArrayString.parse([@tag_one.id.to_s, "ref:#{@tag_two.ref}"].join(','))
    result_ids = ParseIdsRefs.where_pluck_ids(Tag, mixed_array)

    assert_includes result_ids, @tag_one.id
    assert_includes result_ids, @tag_two.id
    assert_equal 2, result_ids.size
  end

  test 'where_pluck_refs with mixed ids and refs returns only refs' do
    mixed_array = CoerceArrayString.parse([@tag_one.id.to_s, "ref:#{@tag_two.ref}"].join(','))
    result_refs = ParseIdsRefs.where_pluck_refs(Tag, mixed_array)

    assert_includes result_refs, @tag_two.ref
    assert_equal 1, result_refs.compact.size
  end

  test 'where with case insensitive ref search' do
    # Test with uppercase ref
    uppercase_ref_array = CoerceArrayString.parse("ref:#{@tag_two.ref.upcase}")
    condition = ParseIdsRefs.where(Tag, uppercase_ref_array)
    result = Tag.where(condition).to_a

    assert_includes result, @tag_two
    assert_equal 1, result.size
  end

  test 'where_pluck_refs with case insensitive ref search' do
    # Test with mixed case refs
    @tag_one.update(ref: 'MixedCase')
    mixed_case_array = CoerceArrayString.parse("ref:#{@tag_one.ref.upcase},ref:#{@tag_two.ref.downcase}")
    result_refs = ParseIdsRefs.where_pluck_refs(Tag, mixed_case_array)

    assert_includes result_refs, @tag_one.ref
    assert_includes result_refs, @tag_two.ref
    assert_equal 2, result_refs.size
  end
end
