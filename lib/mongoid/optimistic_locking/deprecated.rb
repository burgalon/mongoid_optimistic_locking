module Mongoid
  module OptimisticLocking
    module Deprecated

      def save_optimistic!(*args)
        ActiveSupport::Deprecation.warn 'save_optimistic! is deprecated and will be removed. Use save or save! instead', caller
        save! *args
      end

    end
  end
end
