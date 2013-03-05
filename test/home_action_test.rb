require 'test_helper'
require 'hiredis/connection'

class HomeActionTest < Cramp::TestCase
  def app; HomeAction; end

  setup do
    redis.write ['SADD', 'user:1:channels', 'user:1']; redis.read
    redis.write ['SADD', 'user:1:channels', 'room:5']; redis.read
    @waiting = true
  end

  teardown do
    redis.write ['FLUSHDB']; redis.read
  end

  test "must receive a failure status for blank user param" do
    get_body_chunks '/' do |chunks|
      assert_status :failure, chunks.first
    end
    get_body_chunks '/?user=' do |chunks|
      assert_status :failure, chunks.first
    end
  end

  test "must receive a failure status for unknown user" do
    get_body_chunks '/?user=9812098' do |chunks|
      assert_status :failure, chunks.first
    end
  end

  test "must receive an ok status" do
    get_body_chunks '/?user=1' do |chunks|
      assert_status :ok, chunks.first
    end
  end

  test "must proxy message on authorized channel" do
    publish_in_thread('user:1', 'some message')
    get '/?user=1' do |status, headers, body|
      body.each_with_index do |chunk, index|
        case index
        when 0
          assert_status :ok, chunk
          @waiting = false
        when 1
          assert_match(/some message/, chunk)
          stop
        end
      end
    end
  end

  test "musn't proxy message on unauthorized channel" do
    publish_in_thread('room:3', 'some message')
    get '/?user=1' do |status, headers, body|
      body.each_with_index do |chunk, index|
        case index
        when 0
          assert_status :ok, chunk
          @waiting = false
        when 1
          assert_match(/data: noop/, chunk)
          stop
        end
      end
    end
  end

  # FIXME: fix some race conditions, and prefer to discuss with the app instead of relying on a thread.
  test "must refresh subscriptions when receiving a message on user channel" do
    t1 = Thread.new do
      Thread.stop
      redis.write ['SADD', 'user:1:channels', 'room:7']; redis.read
      publish('user:1', 'ADDED ROOM 7')
      Thread.stop
      redis.write ['SREM', 'user:1:channels', 'room:5']; redis.read
      publish('user:1', 'REMOVED ROOM 5')
      Thread.stop
      publish('room:5', 'message for room 5', ensure: false)
      publish('room:7', 'message for room 7')
    end

    messages = [ /ADDED ROOM 7/, /REMOVED ROOM 5/, /message for room 7/ ]
    get '/?user=1' do |status, headers, body|
      body.each_with_index do |chunk, index|
        @waiting = false
        case index
        when 0
          assert_status :ok, chunk
          t1.wakeup
        else
          assert_match messages.shift, chunk unless chunk =~ /data: noop/
          stop if messages.empty?
          begin
            t1.wakeup
          rescue
          end
        end
      end
    end
  end

  def assert_status(status, chunk)
    assert_match %r{<message><status>#{status}</status></message>}, chunk
  end

  def publish_in_thread(channel, message)
    Thread.new do
      Thread.pass while @waiting
      redis.write ['PUBLISH', channel, message]; redis.read
    end
  end

  def publish(channel, message, options = {})
    options[:ensure] = true unless options[:ensure] == false
    loop do
      redis.write ['PUBLISH', channel, message]
      break unless options[:ensure] and redis.read == 0
      sleep 0.1
    end
  end

  def wait
    @waiting = true
    Thread.pass while @waiting
  end

  def redis
    @redis ||= begin
      Sisyphus.redis_url =~ %r{redis://(.+?):(\d+)/(\d+)}
      conn = Hiredis::Connection.new
      conn.connect($1, $2.to_i)
      conn.write ['SELECT', $3]; conn.read
      conn
    end
  end
end
