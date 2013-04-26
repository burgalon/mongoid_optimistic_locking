require 'spec_helper'

describe Mongoid::OptimisticLocking do

  COLLECTIONS = %w(Company Person Car State Flag City)

  before(:all) do

    class Company
      include Mongoid::Document
      field :name
      has_many :people, :class_name => 'Person', :dependent => :destroy
    end

    class Person
      include Mongoid::Document
      include Mongoid::OptimisticLocking
      field :name
      has_many :cars, :dependent => :destroy
    end

    class Car
      include Mongoid::Document
      include Mongoid::OptimisticLocking
      field :color
      belongs_to :person
    end

    class State
      include Mongoid::Document
      field :name
      embeds_one :flag, :inverse_of => :state
      embeds_many :cities, :class_name => 'City', :inverse_of => :state
    end

    class Flag
      include Mongoid::Document
      include Mongoid::OptimisticLocking
      embedded_in :state, :inverse_of => :flag
      field :color
    end

    class City
      include Mongoid::Document
      include Mongoid::OptimisticLocking
      embedded_in :state, :inverse_of => :cities
      field :name
    end

    class Hamburger
      include Mongoid::Document
      include Mongoid::OptimisticLocking
      field :patty
      field :toppings
      validates :patty, presence: true
      validates :toppings, presence: true
    end

  end

  after(:all) { COLLECTIONS.each { |n| Object.send(:remove_const, n) } }
  before { (COLLECTIONS - %w(Flag City)).each { |n| n.constantize.delete_all } }

  context 'without optimistic locking' do

    let!(:c1) { Company.create!(:name => 'Acme') }
    let!(:c2) { Company.find(c1.id) }

    it 'should allow collisions when saving' do
      c1.name = 'Biz'
      c1.save.should be_true
      c2.name = 'Baz'
      c2.save.should be_true
    end

    it 'should allow collisions when destroying' do
      c1.destroy.should be_true
      c2.destroy.should be_true
    end

  end

  context 'optimistic locking on a document' do

    let(:person) { Person.create!(:name => 'Bob') }

    it 'should allow creating' do
      person._lock_version.should == 1
      person.save.should be_true
      person._lock_version.should == 2
      Person.count.should == 1
    end

    it 'should allow updating' do
      person.name = 'Chris'
      person.save.should be_true
      person._lock_version.should == 2
    end

    it 'should allow destroying after create' do
      person.destroy.should be_true
      person.should be_frozen
      person._lock_version.should == 1
      Person.count.should == 0
    end

    it 'should allow destroying from find' do
      another = Person.find(person.id)
      another.destroy.should be_true
      another.should be_frozen
      another._lock_version.should == 1
      Person.count.should == 0
    end

    context 'after updating the first of 3 instances of the same document' do

      before do
        @p1 = person
        @p2 = Person.find(@p1.id)
        @p3 = Person.find(@p1.id)
        @p1.name = 'Michael'
        @p1.save.should be_true
      end

      it 'should raise an exception when updating the second' do
        expect {
          @p2.name = 'George'
          @p2.save
        }.to raise_error(Mongoid::Errors::StaleDocument)
      end
    
      it 'should succeed when updating the second without locking' do
        @p2.name = 'George'
        @p2.unlocked.save.should be_true
      end
    
      it 'should succeed when updating the second without locking, ' +
         'then raise an exception when updating the third' do
        @p2.name = 'George'
        @p2.unlocked.save.should be_true
        expect {
          @p3.name = 'Sally'
          @p3.save
        }.to raise_error(Mongoid::Errors::StaleDocument)
      end

      it 'should raise an exception when destroying the second' do
        expect {
          @p2.destroy
        }.to raise_error(Mongoid::Errors::StaleDocument)
        Person.count.should == 1
      end

      it 'should succeed when destroying the second without locking' do
        @p2.unlocked.destroy
        Person.count.should == 0
      end

      it 'should succeed when destroying the second without locking, ' +
         'and succeed when destroying the third with locking' do
        @p2.unlocked.destroy
        Person.count.should == 0
        @p3.destroy.should
      end

    end

    it 'should destroy dependents with dependent destroy option' do
      Car.count.should == 0
      person.cars.create(:color => 'Red')
      person.destroy
      Car.count.should == 0
    end

    it 'should destroy dependents with dependent destroy option even when they are concurrently edited' do
      car1 = person.cars.create(:color => 'Red')
      car2 = Car.find(car1.id)
      car2.update_attribute :color, 'Green'
      person.reload # important
      person.destroy
      Person.count.should == 0
      Car.count.should == 0
    end

    it 'should give a deprecation warning for #save_optimistic!' do
      ::ActiveSupport::Deprecation.should_receive(:warn).once
      person.save_optimistic!
    end

  end

  context 'optimistic locking on a document with validation' do
    it 'should not incremement lock version when validation fails' do
      burger = Hamburger.new
      burger._lock_version.should == 0
      burger.save.should == false
      burger._lock_version.should == 0
    end

    it 'should allow creation when valid' do
      burger = Hamburger.create({patty: 'beef', toppings: 'bacon'})
      burger._lock_version.should == 1
    end
  end

  context 'optimistic locking on an embeds_one document' do

    let!(:state) { State.new(:name => 'California') }

    it 'should be savable with no embeds' do
      state.name = 'Nevada'
      state.save.should be_true
    end

    it 'should be savable with a built embed' do
      state.build_flag(:color => 'Red')
      state.save.should be_true
    end

    it 'should allow creating the embed' do
      state.create_flag(:color => 'Red')
      state.flag.should be_persisted
    end

    it 'should not increment the lock version when saving the base' do
      state.build_flag(:color => 'Red')
      state.flag._lock_version.should == 0
      state.save
      state.flag._lock_version.should == 0
    end

    it 'should increment lock version when saving the embed' do
      state.build_flag(:color => 'Red')
      state.flag._lock_version.should == 0
      state.flag.save
      state.flag._lock_version.should == 1
    end

    it 'should not raise an exception on saving the base when another process updated it' do
      flag1 = state.create_flag(:color => 'Red')
      flag2 = State.find(state.id).flag
      flag1.color = 'Green'
      state.save # doesn't increment lock version
      flag2.update_attribute(:color, 'Purple').should be_true
    end

    it 'should raise an exception on update when another process updated it' do
      flag1 = state.create_flag(:color => 'Red')
      flag2 = State.find(state.id).flag
      flag1.update_attribute :color, 'Green'
      expect {
        flag2.update_attribute :color, 'Purple'
      }.to raise_error(Mongoid::Errors::StaleDocument)
    end

    it 'should raise an exception on destroy when another process updated it' do
      flag1 = state.create_flag(:color => 'Red')
      flag2 = State.find(state.id).flag
      flag1.update_attribute :color, 'Green'
      expect {
        flag2.destroy
      }.to raise_error(Mongoid::Errors::StaleDocument)
    end

  end

  context 'optimistic locking on an embeds_many document' do

    let!(:state) { State.create!(:name => 'California') }

    it 'should be savable with no embeds' do
      state.name = 'Nevada'
      state.save.should be_true
    end

    it 'should be savable with a built embed' do
      state.cities.build(:name => 'Los Angeles')
      state.save.should be_true
    end

    it 'should allow embedded build to save' do
      city = state.cities.build(:name => 'Los Angeles')
      city.save.should be_true
    end

    it 'should allow embedded create' do
      city = state.cities.create(:name => 'Los Angeles')
      city.should be_persisted
    end

    it 'should not increment the lock version when saving the base' do
      city = state.cities.build(:name => 'Los Angeles')
      city._lock_version.should == 0
      state.save
      city._lock_version.should == 0
    end

    it 'should increment the lock version when building and saving the embed' do
      city = state.cities.build(:name => 'Los Angeles')
      city._lock_version.should == 0
      city.save
      city._lock_version.should == 1
    end

    it 'should increment the lock version when creating the embed' do
      city = state.cities.create(:name => 'Los Angeles')
      city._lock_version.should == 1
    end

  end

  it 'should give a deprecation warning for including Mongoid::Lockable' do
    ::ActiveSupport::Deprecation.should_receive(:warn).once
    Class.new do
      include Mongoid::Document
      include Mongoid::Lockable
    end
  end

end
