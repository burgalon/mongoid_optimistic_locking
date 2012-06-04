module Mongoid
  module OptimisticLocking
    module Operations

      def insert(*args)
        return super unless optimistic_locking?
        increment_lock_version do
          super
        end
      end

      def update(*args)
        return super unless optimistic_locking?
        set_lock_version_for_selector do
          increment_lock_version do
            result = super
            unless Mongoid.database.command({:getlasterror => 1})['updatedExisting']
              raise Mongoid::Errors::StaleDocument.new('update', self)
            end
            result
          end
        end
      end

      def remove(*args)
        return super unless optimistic_locking?
        # unfortunately mongoid doesn't support selectors for remove
        # so we need to handle this making an update and then calling
        # remove
        begin
          update *args
        rescue Mongoid::Errors::StaleDocument
          raise Mongoid::Errors::StaleDocument.new('destroy', self)
          return true
        end
        super
      end

      def atomic_selector
        result = super
        if optimistic_locking? && lock_version_for_selector
          key =
            if metadata && metadata.embedded?
              path = metadata.path(self)
              "#{path.path}._lock_version"
            else
              '_lock_version'
            end
          result[key] = lock_version_for_selector
        end
        result
      end

    end
  end
end
