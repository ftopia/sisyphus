require 'yaml'

class HomeAction < Cramp::Action
  # use_fiber_pool
  # keep_connection_alive

  self.transport = :sse
  periodic_timer :noop, :every => (Sisyphus::Application.env == 'test' ? 2 : 15)
  on_finish :destroy_redis

  # FIXME: authenticate user!
  def start
    if params[:user].nil? or params[:user].strip.empty?
      render_status :failure
      finish
    else
      @user = params[:user]
      create_redis
      try_to_connect
    end
  end

  def create_redis
    @redis = EM::Hiredis.connect(Sisyphus.redis_url)
    @sub   = @redis.pubsub
    ensure_redis_connection
  end

  def destroy_redis
    @sub.close_connection
  rescue
  end

  def noop
    render('noop')
  end

  protected
    # Tries to connect the user.
    def try_to_connect
      @redis.exists("user:#{@user}:channels").callback do |value|
        if value == 0
          render_status :failure
          finish
        else
          render_status :ok
          connect
        end
      end
    end

    # Refreshes subscriptions, then listens for messages to be proxied.
    #
    # Will refresh the subscriptions whenever a message is received on the user
    # channel, since there is a high probability for the message to be related
    # to right changes.
    def connect
      refresh_subscriptions
      @sub.on(:message) do |channel, message|
        render(message)
        refresh_subscriptions if channel =~ /^user:/
      end
    end

    # Fetches the new list of user channels to update the subscriptions.
    def refresh_subscriptions
      @redis.smembers("user:#{@user}:channels").callback do |channels|
        if channels.empty?
          render_status :disconnected
          finish
        else
          subscribe(*channels)
        end
      end
    end

    # Subscribes to the given channels and unsubscribes from removed ones.
    def subscribe(*channels)
      @channels ||= []
      added   = channels - @channels
      removed = @channels - channels
      added.each   { |c| @sub.subscribe(c)   } if added.any?
      removed.each { |c| @sub.unsubscribe(c) } if removed.any?
      @channels = channels
    end

    def render_status(status)
      render Builder::XmlMarkup.new.message { |m| m.status(status.to_s) }
    end

    # Ensures that the Redis server is alive then renders an OK status message if
    # we could connect, otherwise renders an ERROR status message.
    def ensure_redis_connection
      defer = @redis.get('test-redis-connection')
      defer.errback do |e|
        render_status :error
        finish
      end
      #defer.callback { |v| render_status :ok }
    end
end
