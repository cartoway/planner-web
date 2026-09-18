# frozen_string_literal: true

require 'test_helper'
require 'shellwords'
require 'fileutils'

class ScheduleTimeJsTest < ActiveSupport::TestCase
  test 'fieldOptions classifies clock vs duration for Maskito' do
    src = Rails.root.join('app/javascript/lib/schedule_time.js')
    Dir.mktmpdir do |dir|
      mod = File.join(dir, 'schedule_time.mjs')
      FileUtils.cp(src, mod)
      check = File.join(dir, 'check.mjs')
      File.write(check, <<~JS)
        import { fieldOptions, isScheduleTimeName, maskitoTimeParams } from './schedule_time.mjs';
        const assert = (cond, msg) => { if (!cond) { console.error(msg); process.exit(1); } };

        assert(isScheduleTimeName('vehicle_usage[time_window_start]') === true, 'time window');
        assert(isScheduleTimeName('vehicle_usage[time_window_start_day]') === false, 'day excluded');
        assert(fieldOptions('vehicle_usage[time_window_start]').clock === true, 'window is clock');
        assert(fieldOptions('vehicle_usage[rest_start]').clock === true, 'rest_start is clock');
        assert(fieldOptions('vehicle_usage[rest_duration]').clock === false, 'rest_duration is duration');
        assert(fieldOptions('destination[visits_attributes][0][duration]').seconds === true, 'visit duration has seconds');

        const clock = maskitoTimeParams('vehicle_usage[time_window_start]');
        assert(clock.mode === 'HH:MM', 'clock mode HM');
        assert(clock.timeSegmentMaxValues.hours === 23, 'clock max 23');

        const dur = maskitoTimeParams('vehicle_usage[work_time]');
        assert(dur.mode === 'HH:MM', 'work_time HM');
        assert(dur.timeSegmentMaxValues.hours === 99, 'duration max 99');

        const visitDur = maskitoTimeParams('destination[visits_attributes][0][duration]');
        assert(visitDur.mode === 'HH:MM:SS', 'visit duration HMS');
        assert(visitDur.timeSegmentMaxValues.hours === 99, 'visit duration max 99');

        console.log('ok');
      JS
      out = `node #{Shellwords.escape(check)}`
      assert_match(/ok/, out)
      assert $?.success?, out
    end
  end
end
