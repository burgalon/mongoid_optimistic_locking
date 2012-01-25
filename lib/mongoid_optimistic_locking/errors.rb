# encoding: utf-8
module Mongoid #:nodoc
  module Errors #:nodoc

    # Raised when a persistence method ending in ! fails validation. The message
    # will contain the full error messages from the +Document+ in question.
    #
    # @example Create the error.
    #   Validations.new(person.errors)
    class StaleDocument < MongoidError
      attr_reader :document
      def initialize(klass, document)
        @klass = klass
        @document = document
        super(
          translate(
            "stale",
            { :document => document, :klass => klass }
          )
        )
      end
    end
  end
end