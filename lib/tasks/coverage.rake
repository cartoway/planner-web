# frozen_string_literal: true

namespace :coverage do
  desc 'Merge coverage/frontend and coverage/backend SimpleCov resultsets (enforces 84% minimum)'
  task :collate do
    require_relative '../../test/simplecov_setup'
    SimplecovSetup.collate!
  end
end
