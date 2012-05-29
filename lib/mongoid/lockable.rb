module Mongoid

  module Lockable

    extend ActiveSupport::Concern

    included do
      ActiveSupport::Deprecation.warn 'Mongoid::Lockable is deprecated and will be removed. Use Mongoid::OptimisticLocking instead.', caller
      include Mongoid::OptimisticLocking
    end

  end
end
