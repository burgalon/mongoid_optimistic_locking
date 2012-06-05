module Mongoid
  module OptimisticLocking
    module Operations

      def insert(options = {})
        return super unless optimistic_locking?
        increment_lock_version do
          super
        end
      end

      def update(options = {})
        return super unless optimistic_locking?
        set_lock_version_for_selector do
          increment_lock_version do
            result = super
            getlasterror = Mongoid.database.command({:getlasterror => 1})
            if result && !getlasterror['updatedExisting']
              raise Mongoid::Errors::StaleDocument.new('update', self)
            end
            result
          end
        end
      end

      def remove(options = {})
        return super unless optimistic_locking? && persisted?
        # we need to just see if the document exists and got updated with
        # a higher lock version
        existing = _reload # get the current root or embedded document
        if existing.present? && existing['_lock_version'] &&
           existing['_lock_version'].to_i > _lock_version.to_i
          raise Mongoid::Errors::StaleDocument.new('destroy', self)
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
