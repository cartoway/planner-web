# frozen_string_literal: true

module OperationStops
  # Single source for stop row / fiche / live-patch badges.
  # Glossary: plan_gap = vs planned departure; window_late = vs visit time-window close; phase late = ETA risk.
  class Asides
    LIST_CSS = {
      bad: 'operation-gap is-bad',
      exception: 'operation-gap is-exception',
      now: 'badge operation-now',
      ok: 'operation-gap is-ok',
      late: 'operation-gap is-late'
    }.freeze

    FICHE_CSS = {
      bad: 'badge text-bg-danger',
      exception: 'badge operation-exception',
      now: 'badge text-bg-info',
      ok: 'badge text-bg-success',
      late: 'badge text-bg-warning'
    }.freeze

    def self.call(stop)
      new(stop).call
    end

    def self.fiche_css(tone)
      FICHE_CSS[tone.to_sym] || 'badge text-bg-secondary'
    end

    def initialize(stop)
      @stop = stop
    end

    def call
      rows.map { |row| row.merge(label: label_for(row), css: LIST_CSS[row[:tone]]) }
    end

    private

    attr_reader :stop

    def rows
      phase = stop.phase
      return [badge(:status, :bad)] if phase == 'failed'
      return [badge(:exception, :exception)] if phase == 'exception'
      return [badge(:status, :now)] if phase == 'started'
      return [badge(:en_route, :now)] if phase == 'current'

      delay = stop.delay_minutes
      window = stop.time_window_delay_minutes
      out = []
      out << badge(:window_late, :late, count: window) if window&.positive?

      if status_with_optional_window?(phase, delay)
        out << badge(:status, :ok)
      elsif delay&.positive?
        tone = delay > OperationStop::LATE_AFTER_MINUTES ? :late : :ok
        out << badge(:plan_gap, tone, count: delay)
      elsif delay
        out << badge(:delay, :ok, count: delay)
      elsif phase == 'late'
        out << badge(:late_risk, :late)
      end
      out
    end

    # Delivered/store/rest keep a status chip even when a window-late alert is also shown.
    # delay == 0 (on plan) must still show status — not a "0 min" chip.
    def status_with_optional_window?(phase, delay)
      return true if stop.kind == 'store' && stop.treated?
      return true if phase == 'delivered' && stop.kind == 'rest'
      return true if phase == 'delivered' && !delay&.positive?

      false
    end

    def badge(kind, tone, count: nil)
      { kind: kind.to_s, tone: tone, count: count }.compact
    end

    def label_for(row)
      case row[:kind]
      when 'status' then stop.status_label
      when 'en_route' then I18n.t('operations.show.en_route')
      when 'exception' then I18n.t('plannings.edit.stop_status.exception')
      when 'plan_gap' then I18n.t('operations.show.plan_gap', count: row[:count])
      when 'window_late' then I18n.t('operations.show.window_late', count: row[:count])
      when 'delay' then format_signed_minutes(row[:count])
      when 'late_risk' then I18n.t('operations.show.late_risk')
      end
    end

    def format_signed_minutes(minutes)
      minutes.positive? ? "+#{minutes} min" : "#{minutes} min"
    end
  end
end
