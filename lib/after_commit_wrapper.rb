# Copyright © Cartoway, 2025
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

# Solution inspired by Evil Martians' "Rails after_commit everywhere"
# https://evilmartians.com/chronicles/rails-after_commit-everywhere
# This ensures background jobs are only enqueued after database transactions are committed

class AfterCommitWrapper
  def initialize(&block)
    @callback = block
  end

  def committed!(*)
    @callback.call
  end

  def before_committed!(*); end

  def rolledback!(*); end

  def trigger_transactional_callbacks?
    true
  end
end

module AfterCommitHelper
  refine ::Object do
    def after_commit(connection: ActiveRecord::Base.connection, &block)
      if connection.transaction_open?
        connection.add_transaction_record(AfterCommitWrapper.new(&block))
      else
        # No transaction, execute immediately
        yield
      end
    end

    def after_commit_job(job_class, *args, **options)
      after_commit do
        DelayedJobManager.enqueue_with_delay(job_class, *args, **options)
      end
    end
  end
end
