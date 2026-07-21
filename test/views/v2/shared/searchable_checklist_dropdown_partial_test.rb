# frozen_string_literal: true

require 'test_helper'

class SearchableChecklistDropdownPartialTest < ActionView::TestCase
  test 'happy path wires search filter, max active and reset defaults' do
    items = [
      { id: 'name', label: 'Name', checked: true },
      { id: 'city', label: 'City', checked: true },
      { id: 'ref', label: 'Reference', checked: false }
    ]

    render partial: 'v2/shared/searchable_checklist_dropdown', locals: {
      items: items,
      max_active: 2,
      default_active_ids: %w[name city],
      toggle_title: 'Columns',
      count_label: '2 / 2',
      global_action_label: 'Reset to defaults',
      global_action_disabled: true,
      id_prefix: 'test-checklist'
    }

    assert_select '.searchable-checklist-dropdown[data-controller="v2--searchable-checklist-dropdown"]', 1
    assert_select '[data-v2--searchable-checklist-dropdown-max-active-value="2"]', 1
    assert_select 'input[type=search][data-action="input->v2--searchable-checklist-dropdown#filter"]', 1
    assert_select 'button[data-action="click->v2--searchable-checklist-dropdown#resetDefaults"][disabled]', 1
    assert_select '.searchable-checklist-dropdown-option[data-filter-label]', 3
    assert_select '#test-checklist-name[checked]', 1
    assert_select '#test-checklist-city[checked]', 1
    assert_select '#test-checklist-ref', 1
    assert_select '#test-checklist-ref[checked]', count: 0
    assert_select 'input[data-action="change->v2--searchable-checklist-dropdown#change"]', 3
    assert_select '.searchable-checklist-dropdown-menu.show', count: 0
  end

  test 'open local shows the menu for Lookbook-style previews' do
    render partial: 'v2/shared/searchable_checklist_dropdown', locals: {
      items: [{ id: 'name', label: 'Name', checked: true }],
      max_active: 2,
      default_active_ids: %w[name],
      toggle_title: 'Columns',
      open: true
    }

    assert_select '.searchable-checklist-dropdown-menu.show', 1
    assert_select '.searchable-checklist-dropdown-toggle[aria-expanded="true"]', 1
  end
end
