# mongoid\_optimistic\_locking

This gem helps to abstract ["Update if current"](http://www.mongodb.org/display/DOCS/Atomic+Operations) method which may be used as a replacement for [transactions in Mongo](http://www.mongodb.org/display/DOCS/Developer+FAQ#DeveloperFAQ-HowdoIdotransactions%2Flocking%3F)
The gem is an addon over Mongoid ODM.

## Compatibility

So far it works with the Rails 3 and Mongoid 2.4.

Created branch for edge *Mongoid 3*

## Rails 3 Installation

Add the gem to your gemfile

    gem 'mongoid_optimistic_locking'

## Usage

To use it, all you have to do is add include Mongoid::Lockable

    class Post
      include Mongoid::Document
      include Mongoid::Lockable

      field :text
    end

This will add a _lock_version field in the document which will be incremented every time a save is called.
In order a to save a document in a save manner, use the new <code>save_optimistic!</code> and <code>rescue Mongoid::Errors::StaleDocument</code> to handle applicative logic in case the object was changed.

For example:

    class PostController < ApplicationController
        ## Adds an "UPDATE: ...some text..." to an existing document
        def add_update
            begin
                post = Post.find(params[:id])
                post.text += "---UPDATE---  " + params[:more_text]
                post.save_optimistic!
            rescue Mongoid::Errors::StaleDocument
                retry
            end
        end
    end

That's it

## Open sourced by

[Boxee](http://www.boxee.tv)


## References
[Mongo Developer FAQ - How do I do transactions/locking?](http://www.mongodb.org/display/DOCS/Developer+FAQ#DeveloperFAQ-HowdoIdotransactions%2Flocking%3F)

[Mongo Atomic Operations - "Update if Current"](http://www.mongodb.org/display/DOCS/Atomic+Operations)
