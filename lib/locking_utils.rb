module LockingUtils
  class ResourceLockedError < StandardError; end

  # Lock all given records (can be of different models) in a single transaction.
  # Raises ResourceLockedError if any lock cannot be obtained immediately.
  def with_locks_on(*records)
    klasses = records.flatten.group_by(&:class)
    ApplicationRecord.transaction do
      klasses.each do |klass, recs|
        recs.each do |rec|
          begin
            klass.where(id: rec.id).lock('FOR UPDATE NOWAIT').first!
          rescue ActiveRecord::LockWaitTimeout, ActiveRecord::StatementInvalid => e
            if e.message =~ /could not obtain lock|NOWAIT/
              raise ResourceLockedError, I18n.t('errors.database.locked.resource_locked_with_id', klass: klass.name, id: rec.id)
            end
            raise
          end
        end
      end
      yield
    end
  end
end
