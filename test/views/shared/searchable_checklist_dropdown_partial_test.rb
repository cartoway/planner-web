# frozen_string_literal: true

require 'test_helper'

class SearchableChecklistDropdownPartialV1Test < ActionView::TestCase
  test 'renders searchable checklist dropdown with search and global actions' do
    render partial: 'shared/searchable_checklist_dropdown', locals: {
      id: 'demo-selector',
      id_prefix: 'demo',
      items: [
        { id: 1, label: 'Route A', checked: true, filter_label: 'route a' },
        { id: 2, label: 'Route B', checked: false, filter_label: 'route b' }
      ]
    }

    assert_select '#demo-selector[data-searchable-checklist-dropdown]'
    assert_select '[data-searchable-checklist-filter]'
    assert_select '[data-searchable-checklist-action=all]'
    assert_select '[data-searchable-checklist-action=clear]'
    assert_select '[data-searchable-checklist-action=reverse]'
    assert_select '.searchable-checklist-dropdown-option', 2
    assert_select '#demo-1[checked]'
    assert_select '#demo-2[checked]', count: 0
    assert_select '[data-searchable-checklist-tag-filter]', count: 0
  end

  test 'renders tag filter chips when filter_tags are provided' do
    render partial: 'shared/searchable_checklist_dropdown', locals: {
      id: 'tagged-selector',
      id_prefix: 'tagged',
      filter_tags: [
        { id: 10, label: 'Fridge', color: '#336699', icon: 'fa-snowflake-o' },
        { id: 11, label: 'Long haul', color: '#777777', icon: 'fa-flag' }
      ],
      items: [
        { id: 1, label: 'Route A', checked: true, filter_label: 'route a fridge', data: { tag_ids: '10' } },
        { id: 2, label: 'Route B', checked: false, filter_label: 'route b', data: { tag_ids: '' } }
      ]
    }

    assert_select '[data-searchable-checklist-tag-filter]', 2
    assert_select '[data-searchable-checklist-tag-filter][value=10]'
    assert_select '[data-searchable-checklist-tag-filter][value=11]'
    assert_select '.searchable-checklist-dropdown-option[data-tag-ids=10]', 1
    assert_includes rendered, I18n.t('execution.modal.filter_by_tag')
  end
end
