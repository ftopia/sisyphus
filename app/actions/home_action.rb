require 'builder'

class HomeAction < Cramp::Action
  self.transport = :sse

  on_start  :create_redis
  on_finish :destroy_redis

  periodic_timer :noop, :every => 15

  def start
    rooms = params[:rooms] || []
    if rooms.empty?
      render_status :disconnected
      finish
    else
      create_redis
      subscribe(*rooms)
    end
  end

  def create_redis
    @sub = EM::Hiredis.connect('redis://localhost:6379/0').pubsub
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
    def subscribe(*rooms)
      rooms.each { |room| @sub.subscribe(room) }
      @sub.on(:message) { |channel, message| render(message) }
    end

    # Formats a status message.
    def render_status(status)
      render Builder::XmlMarkup.new.message { |m| m.status(status.to_s) }
    end

    # Ensures that the Redis server is alive. Renders an OK status message if
    # connection was possible, otherwise renders and ERROR status message.
    def ensure_redis_connection
      defer = @sub.get('test-redis-connection')
      defer.errback do |e|
        render_status :error
        finish
      end
      defer.callback do |value|
        render_status :ok
      end
    end
end
