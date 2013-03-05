ENV['RACK_ENV'] = 'test'
require "bundler"
Bundler.setup
Bundler.require :default, :test

require File.expand_path('../../application', __FILE__)

class Cramp::Body
  def each_with_index(&block)
    index = -1
    each { |chunk| block.call(chunk, index += 1) }
  end
end

class Cramp::TestCase
  def app
    Sisyphus::Application
  end
end
