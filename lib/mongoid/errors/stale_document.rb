require 'mongoid/errors/mongoid_error'

module Mongoid
  module Errors

    # Raised when trying to update a document that has been updated by
    # another process.
    #
    # @example Create the error.
    #   StaleDocument.new('update', document)
    class StaleDocument < MongoidError

      attr_reader :action, :document

      def initialize(action, document)
        @action = action
        @document = document

        super(
          translate(
            "stale_document.#{action}",
            { :klass => document.class.name }
          )
        )
      end
    end
  end
end