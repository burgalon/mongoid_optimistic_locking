require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class Post
  include Mongoid::Document
  include Mongoid::Lockable

  field :title
end

describe Mongoid::Lockable do
  context 'just working' do
    before :all do
      @post = Post.create(name: 'original-name')
      @post._lock_version.should == 1
    end

    it "works!" do
      @post.name = 'changed-name'
      @post.save_optimistic!.should == true
      @post._lock_version.should == 2
      @post.reload
      @post.name.should == 'changed-name'
      @post._lock_version.should == 2
    end

    it "raises Stale exception if another process/background code updates the object" do
      post_clone = Post.find(@post.id)
      # the before_filter should increments the version by one, thus making the object stale
      post_clone.name = 'changed-in-background'
      post_clone.save

      @post.name = 'changed-name'
      expect {@post.save_optimistic!}.to raise_error(Mongoid::Errors::StaleDocument)

      # Should fail again if still not refreshed
      # i.e: test that _lock_version is decremented upon failure
      expect {@post.save_optimistic!}.to raise_error(Mongoid::Errors::StaleDocument)

      # Test StaleDocument error
      begin
        @post.save_optimistic!
      rescue Mongoid::Errors::StaleDocument => e
        e.message().should match('Post')
      end

      @post.reload
      @post.name.should == 'changed-in-background'

      post_clone.name = 'changed-in-background'
      post_clone.save
    end
  end
end