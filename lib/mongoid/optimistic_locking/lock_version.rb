module Mongoid
  module OptimisticLocking
    module LockVersion

      LOCKING_FIELD = :_lock_version

      private

      attr_reader :lock_version_for_selector

      def set_lock_version_for_selector
        @lock_version_for_selector = self[LOCKING_FIELD]
        yield
      rescue Exception
        @lock_version_for_selector = nil
        raise
      end

      def increment_lock_version
        self[LOCKING_FIELD] = self[LOCKING_FIELD] ? self[LOCKING_FIELD] + 1 : 1
        yield
      rescue Exception
        self[LOCKING_FIELD] = self[LOCKING_FIELD] ? self[LOCKING_FIELD] - 1 : 0
        raise
      end

    end
  end
end
