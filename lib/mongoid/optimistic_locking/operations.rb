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
            unless mongo_session.command({:getlasterror => 1})['updatedExisting']
              raise Mongoid::Errors::StaleDocument.new('update', self)
            end
            result
          end
        end
      end

      def remove(*args)
        return super unless optimistic_locking?
        set_lock_version_for_selector do
          result = super
          unless mongo_session.command({:getlasterror => 1})['updatedExisting']
            raise Mongoid::Errors::StaleDocument.new('destroy', self)
          end
          result
        end
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
