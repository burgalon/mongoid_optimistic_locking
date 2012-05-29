module Mongoid
  module OptimisticLocking
    module Unlocked

      extend ActiveSupport::Concern

      def unlocked
        Threaded.unlocked = true
        self
      end

      def optimistic_locking?
        Threaded.optimistic_locking?
      end

      module ClassMethods

        def unlocked
          Threaded.unlocked = true
        end

      end

    end
  end
end
