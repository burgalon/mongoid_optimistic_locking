require 'rubygems'
require 'bundler'
Bundler.setup

require 'mongoid'

Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db("mongoid_optimistic_locking_test")
end

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))


require 'mongoid_optimistic_locking'
require 'rspec'