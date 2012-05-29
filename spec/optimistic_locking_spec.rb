require 'spec_helper'

describe Mongoid::OptimisticLocking do

  context 'without optimistic locking' do

    let(:company_class) do
      Class.new do
        include Mongoid::Document
        self.collection_name = 'companies' 
        field :name
      end
    end

    it 'should allow collisions' do
      c1 = company_class.create!(:name => 'Acme')
      c2 = company_class.find(c1.id)
      c1.name = 'Biz'
      c1.save.should == true
      c2.name = 'Baz'
      c2.save.should == true
    end

  end

  context 'three instances of the same document' do

    let(:person_class) do
      Class.new do
        include Mongoid::Document
        include Mongoid::OptimisticLocking
        self.collection_name = 'people' 
        field :name
      end
    end

    before do
      @p1 = person_class.create!(:name => 'Bob')
      @p2 = person_class.find(@p1.id)
      @p3 = person_class.find(@p1.id)
    end

    context 'after updating the first' do

      before do
        @p1.name = 'Michael'
        @p1.save.should == true
      end

      it 'should fail when updating the second' do
        expect {
          @p2.name = 'George'
          @p2.save
        }.to raise_error(Mongoid::Errors::StaleDocument)
      end

      it 'should succeed when updating the second without locking' do
        @p2.name = 'George'
        @p2.unlocked.save.should == true
      end

      it 'should succeed when updating the second without locking, ' +
         'then fail when updating the third' do
        @p2.name = 'George'
        @p2.unlocked.save.should == true
        expect {
          @p3.name = 'Sally'
          @p3.save
        }.to raise_error(Mongoid::Errors::StaleDocument)
      end

      it 'should fail when destroying the second' do
        expect {
          @p2.destroy
        }.to raise_error(Mongoid::Errors::StaleDocument)
      end

      it 'should succeed when destroying the second without locking' do
        @p2.unlocked.destroy
      end

      it 'should succeed when destroying the second without locking, ' +
         'then fail when destroying the third' do
        @p2.unlocked.destroy
        expect {
          @p3.destroy
        }.to raise_error(Mongoid::Errors::StaleDocument)
      end

    end

    it 'should give a deprecation warning for #save_optimistic!' do
      ::ActiveSupport::Deprecation.should_receive(:warn).once
      @p1.save_optimistic!
    end

    it 'should give a deprecation warning for including Mongoid::Lockable' do
      ::ActiveSupport::Deprecation.should_receive(:warn).once
      Class.new do
        include Mongoid::Document
        include Mongoid::Lockable
      end
    end

  end

end
