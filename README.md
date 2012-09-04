# mongoid\_optimistic\_locking

This gem helps to abstract the ["Update if Current"](http://www.mongodb.org/display/DOCS/Atomic+Operations#AtomicOperations-%22UpdateifCurrent%22) method which may be used as a replacement for [transactions in Mongo](http://docs.mongodb.org/manual/faq/developers/#how-do-i-do-transactions-and-locking-in-mongodb).

The gem is an addon over [Mongoid ODM](http://mongoid.org/) and is based on [ActiveRecord's Optimistic Locking](http://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html).

## Compatibility

So far it works with the Rails 3 and Mongoid 2.4.x.

Created branch for edge *Mongoid 3*.

## Rails 3 Installation

Add the gem to your `Gemfile`:

    gem 'mongoid_optimistic_locking'

## Usage

To use it, all you have to do is add include `Mongoid::OptimisticLocking`:

    class Post
      include Mongoid::Document
      include Mongoid::OptimisticLocking
      field :text
    end

This will add a `_lock_version` field in the document which will be incremented every time a save is called.
Be sure to rescue `Mongoid::Errors::StaleDocument` to handle applicative logic in case the object was changed.

For example:

    class PostController < ApplicationController
      ## Adds an "UPDATE: ...some text..." to an existing document
      def add_update
        begin
          post = Post.find(params[:id])
          post.text += "---UPDATE---  " + params[:more_text]
          post.save
        rescue Mongoid::Errors::StaleDocument
          retry
        end
      end
    end

That's it!

## Embedded Document Caveats

While `Mongoid::OptimisticLocking` can be used to some degree within embedded documents, there are certain limitations due to Mongoid's document embedding callback structure. Consider the following example:

    class Post
      include Mongoid::Document
      field :text
      embeds_many :comments
    end

    class Comment
      include Mongoid::Document
      include Mongoid::OptimisticLocking
      embedded_in :post
      field :text
    end

    post = Post.new
    comment = post.comments.build(:text => 'hello')
    comment.save # will use optimistic locking checks
    post.save # will not use optimistic locking checks

## Open sourced by

[Boxee](http://www.boxee.tv)

## References
[Mongo Developer FAQ - How do I do transactions/locking?](http://docs.mongodb.org/manual/faq/developers/#how-do-i-do-transactions-and-locking-in-mongodb)

[Mongo Atomic Operations - "Update if Current"](http://www.mongodb.org/display/DOCS/Atomic+Operations#AtomicOperations-%22UpdateifCurrent%22)

[Presentation from "Startup Day" on Mongoid Optimistic Locking](https://speakerdeck.com/u/burgalon/p/mongoid-optimistic-locking)
