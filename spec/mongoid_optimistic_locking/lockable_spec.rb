require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class Post
  include Mongoid::Document
  include Mongoid::Lockable

  field :title

  embeds_many :comments
end

class Comment
  include Mongoid::Document
  include Mongoid::Lockable

  field :text
  embedded_in :post
end

describe Mongoid::Lockable do
  before :all do
    @post = Post.create(:text => 'original-text')
    @post._lock_version.should == 1
  end

  it "simulate a migration situation in which _lock_version did not exist" do
    Post.update_all(:_lock_version => nil)
    @post.reload.save_optimistic!.should == true
  end

  describe "test root documents" do
    it "saves regularly if there's no other process changing the data in the background" do
      @post.text = 'changed-text'
      @post.save_optimistic!.should == true
      @post._lock_version.should == 2
      @post.reload
      @post.text.should == 'changed-text'
      @post._lock_version.should == 2
    end

    it "raises Stale exception if another process/background code updates the object" do
      post_clone = Post.find(@post.id)
      # the before_filter should increments the version by one, thus making the object stale
      post_clone.text = 'changed-in-background'
      post_clone.save

      @post.text = 'changed-text'
      expect { @post.save_optimistic! }.to raise_error(Mongoid::Errors::StaleDocument)

      # Should fail again if still not refreshed
      # i.e: test that _lock_version is decremented upon failure
      expect { @post.save_optimistic! }.to raise_error(Mongoid::Errors::StaleDocument)

      # Test StaleDocument error
      begin
        @post.save_optimistic!
      rescue Mongoid::Errors::StaleDocument => e
        e.message().should match('Post')
      end

      @post.reload
      @post.text.should == 'changed-in-background'

      post_clone.text = 'changed-in-background'
      post_clone.save
    end
  end

  describe "test embedded documents" do
    before :all do
      @post = Post.create(:text => 'original-text')
      @comment = @post.comments.create!(:text => 'First comment')
    end

    it "saves regularly if there's no other process changing the data in the background" do
      @comment.text = 'First comment updated!'
      @comment.save_optimistic!.should == true
      @comment._lock_version.should == 2
      @comment.reload
      @comment.text.should == 'First comment updated!'
      @comment._lock_version.should == 2
    end

    it "raises Stale exception if another process/background code updates the object" do
      @comment_clone = Post.find(@post.id).comments.find(@comment.id)
      # the before_filter should increments the version by one, thus making the object stale
      @comment_clone.text = 'changed-in-background'
      @comment_clone.save

      @comment.text = 'changed-text'
      expect { @comment.save_optimistic! }.to raise_error(Mongoid::Errors::StaleDocument)

      # Should fail again if still not refreshed
      # i.e: test that _lock_version is decremented upon failure
      expect { @comment.save_optimistic! }.to raise_error(Mongoid::Errors::StaleDocument)

      # Test StaleDocument error
      begin
        @comment.save_optimistic!
      rescue Mongoid::Errors::StaleDocument => e
        e.message().should match('Comment')
      end

      @comment.reload
      @comment.text.should == 'changed-in-background'

      @comment_clone.text = 'changed-in-background'
      @comment_clone.save
    end
  end
end
