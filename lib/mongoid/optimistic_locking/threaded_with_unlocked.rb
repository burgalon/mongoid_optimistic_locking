module Mongoid
  module OptimisticLocking
    module ThreadedWithUnlocked

      extend ActiveSupport::Concern
      
      module ClassMethods

        def optimistic_locking?
          !unlocked
        end

        def unlocked
          !!Thread.current["[mongoid]:unlocked"]
        end

        def unlocked=(value)
          Thread.current["[mongoid]:unlocked"] = value
        end

        def clear_options!
          self.unlocked = false
          super
        end

      end

    end
  end
end
