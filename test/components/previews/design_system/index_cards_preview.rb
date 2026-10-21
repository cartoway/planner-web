# frozen_string_literal: true

module DesignSystem
  # Shared v2 index card list pattern (see v2/_index_cards.scss).
  class IndexCardsPreview < ApplicationPreview
    # Plain index list: operations (real chrome) + deliverable units cards.
    def index_with_cards
      render_with_template
    end

    # Same indexes in a phone-width frame (forced mobile card stack).
    def index_with_cards_mobile
      render_with_template
    end

    # Selection mode (Sélectionner reveals checkboxes + bulk).
    def with_selection
      render_with_template
    end

    # Map-backed index (destinations / stores): desktop list panel over map.
    def index_with_cards_and_map
      render_with_template
    end

    # Map-backed index on phone: Liste / Carte panes side by side.
    def index_with_cards_and_map_mobile
      render_with_template
    end
  end
end
