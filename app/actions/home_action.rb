require 'yaml'

class HomeAction < Cramp::Action
  use_fiber_pool
  self.transport = :sse

  #keep_connection_alive
  periodic_timer :noop, :every => 15

  on_finish :destroy_redis

  # FIXME: authenticate user!
  def start
    if params[:user] and params[:user].strip.empty?
      render_status :failure
      finish
    else
      @user = params[:user]
      create_redis
      connect
    end
  end

  def create_redis
    @redis = EM::Hiredis.connect(redis_url)
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

  private
    def connect
      refresh_subscriptions
      @sub.on(:message) do |channel, message|
        render(message)
        refresh_subscriptions if channel =~ /^user:/
      end
    end

    def refresh_subscriptions
      @redis.lrange("user:#{@user}:channels", 0, -1).callback do |channels|
        subscribe("user:#{@user}", *channels)
      end
    end

    # Subscribes to new channels and unsubscribes from removed ones.
    def subscribe(*channels)
      @channels ||= []
      added   = channels - @channels
      removed = @channels - channels
      @sub.subscribe(*added) if added.any?
      @sub.unsubscribe(*removed) if removed.any?
      @channels = channels
    end

    def render_status(status)
      render Builder::XmlMarkup.new.message { |m| m.status(status.to_s) }
    end

    # Ensures that the Redis server is alive. Renders an OK status message if
    # we could connect, otherwise renders an ERROR status message.
    def ensure_redis_connection
      defer = @redis.get('test-redis-connection')
      defer.errback do |e|
        render_status :error
        finish
      end
      defer.callback { |v| render_status :ok }
    end

  private
    def redis_url
      @redis_url ||= begin
        rack_env = ENV['RACK_ENV']
        yml = YAML.load_file(File.expand_path('../../../config/redis.yml', __FILE__))
        yml[rack_env]['url']
      end
    end
end
