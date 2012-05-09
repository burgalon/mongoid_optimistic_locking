require 'mongoid'
require 'mongoid_optimistic_locking/errors'

module Mongoid::Lockable
  extend ActiveSupport::Concern

  included do
    field :_lock_version, :type => Integer, :default => 0
    alias :atomic_selector_old :atomic_selector

    # add callback to save tags index
    before_save do
      self._lock_version=0 if self._lock_version.nil?
      self._lock_version += 1
    end
  end

  def optimistic_atomic_selector
    s = atomic_selector_old
    if metadata && metadata.embedded?
      path = metadata.path(self)
      key = "#{path.path}._lock_version"
    else
      key = '_lock_version'
    end
    s[key] = _lock_version==1 ? nil : _lock_version-1
    s
  end

  def save_optimistic!(options = {}, &block)
    instance_eval do
      alias :atomic_selector :optimistic_atomic_selector
    end
    ret = save!
    instance_eval do
      alias :atomic_selector :atomic_selector_old
    end
    result =  Mongoid.database.command({:getlasterror => 1})
    unless result["updatedExisting"]
      self._lock_version -= 1
      raise Mongoid::Errors::StaleDocument.new(self.class, self)
    end
    ret
  end

end
