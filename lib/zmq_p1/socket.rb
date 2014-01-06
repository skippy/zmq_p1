# NOTE: design influenced by Akka ZeroMQ, Celluloid-zmq, and ZeroRPC
# some of the documentation notes came from the Akka libs, which are very well documented
class ZMQP1
  class Socket
    extend Forwardable

    attr_reader :linger, :raw_socket, :raw_poller, :address, :attachment_type, :retries, :timeout


    # Create a new socket
    def initialize(type, opts={})
      @type       = type
      @raw_socket = create_raw_socket(type)
      @linger     = opts.fetch(:linger, 0)
      @retries    = opts.fetch(:retries, 3)
      @timeout    = opts.fetch(:timeout, 10)
      self.raw_socket.identity = opts[:identity]
      at_exit do
        self.close
      end
      log('initialized')
    end


    # Connect to the given 0MQ address
    # Address should be in the form: tcp://1.2.3.4:5678
    def connect(address)
      attach(:connect, address)
      true
    end


    # Bind to the given 0MQ address
    # Address should be in the form:
    #  tcp://*:5678
    #  tcp://127.0.0.1:1234
    def bind(address)
      attach(:bind, address)
    end


    # Determines how long pending messages which have not been set will linger
    # in memory after the socket is closed.  This impacts what happens upon termination
    #
    # The different behaviors are as follows:
    #   -1: (Default Value) specifies an infinite linger period; attempting to terminate
    #       the socket's context shall block until all pending messages have been sent
    #    0: no linger period; pending messages are discarded immediately when the socket is closed
    #  > 0: the upper bound for the linger period in milliseconds.  Pending msgs will not be discarded
    #       after the socket is closed.  Context will terminate once all msgs are sent OR the linger
    #       period has passed
    def linger=(value)
      @linger = value || -1
      rc = self.raw_socket.setsockopt(::ZMQ::LINGER, value)
      check_rc!(rc, err_label: 'linger')
    end


    def close(method=:abrupt)
      begin
        case method
        when :abrupt
          self.linger = 0
        end
      rescue IOError
        #swallow if socket already closed
      end
      log('closing')
      @raw_socket.close
    end


    def reconnect
       close(:abrupt)
       @raw_socket = create_raw_socket(@type)
       if self.attachment_type && self.address
         attach(self.attachment_type, self.address)
       end
       @poller = ZMQ::Poller.new
       @poller.register(@raw_socket, ZMQ::POLLIN)
    end



    def attach(type, address)
      unless %i[connect bind].include?(type)
        raise ArgumentError, "Attachment type is not allowed"
      end
      @address = address
      @attachment_type = type
      rc = self.raw_socket.send(@attachment_type, @address)
      check_rc!(rc, err_label: @attachment_type, err_msg: "couldn't connect to #{@address}")
      log(@attachment_type, msg: "connected to #{@address}")
    end
    private :attach


    def create_raw_socket(type)
      ZMQP1.context.socket ::ZMQ.const_get(type.to_s.upcase)
    end
    private :create_raw_socket


    def log(label, type: 'debug', msg: nil)
      ZMQP1.logger.send(type){ "#{label} : #{self.raw_socket.identity} (#{self.class} : #{self.raw_socket.object_id}) #{msg}" }
    end
    private :log


    def check_rc!(response, err_label: ZMQP1::Util.required_arg, log_type: 'error', err_msg: nil)
      return if ::ZMQ::Util.resultcode_ok? response
      err_msg ||= 'error'
      err_msg << ": #{::ZMQ::Util.error_string} (#{::ZMQ::Util.errno})"
      log(err_label, type: log_type, msg: err_msg)
      raise IOError, err_msg
    end
    private :check_rc!


    def_delegators :@raw_socket, :identity, :identity=
  end


  # Readable 0MQ sockets have a read method
  module ReadableSocket
    # extend Forwardable

    # always set LINGER on readable sockets
    def bind(addr)
      self.linger = @linger
      super(addr)
    end

    def connect(addr)
      self.linger = @linger
      super(addr)
    end


    def read
      self.retries.times do
        if self.raw_poller.poll(self.timeout) > 0
          rc = self.raw_socket.recv_string(buffer='')
          check_rc!(rc, err_label: 'read', err_msg: "error receiving ZMQ string")
          return Message::load(buffer)
        else
          self.reconnect
        end
      end
    end


    def read_message
      read.message
    end
  end


  # Writable 0MQ sockets have a send method
  module WritableSocket
    # Send a message to the socket
    def write(message, headers={})
      msg = message.is_a?(Message) ? message : Message.new(:message => message, :headers => headers)
      msg = msg.serialize
      rc  = self.raw_socket.send_string(msg)
      check_rc!(rc, err_label: 'write', err_msg: "error sending ZMQ string")
    end
    alias_method :<<, :write
  end


  # RequestSockets are the counterpart of ResponseSockets (REQ/REP)
  # Request is analogous to client
  class RequestSocket < Socket
    include ReadableSocket
    include WritableSocket

    def initialize(opts={})
      super :req, opts
    end
  end


  # ResponseSocket are the counterpart of RequestSocket (REQ/REP)
  # Response is analogous to server
  class ResponseSocket < Socket
    include ReadableSocket
    include WritableSocket

    def initialize(opts={})
      super :rep, opts
    end
  end


  # DealerSockets are like RequestSockets but more flexible
  class DealerSocket < Socket
    include ReadableSocket
    include WritableSocket

    def initialize(opts={})
      super :dealer, opts
    end
  end


  # RouterSockets are like ResponseSocket but more flexible
  class RouterSocket < Socket
    include ReadableSocket
    include WritableSocket

    def initialize(opts={})
      super :router, opts
    end
  end


  # PushSockets are the counterpart of PullSockets (PUSH/PULL)
  class PushSocket < Socket
    include WritableSocket

    def initialize(opts={})
      super :push, opts
    end
  end


  # PullSockets are the counterpart of PushSockets (PUSH/PULL)
  class PullSocket < Socket
    include ReadableSocket

    def initialize(opts={})
      super :pull, opts
    end
  end


  # PubSockets are the counterpart of SubSockets (PUB/SUB)
  class PubSocket < Socket
    include WritableSocket

    def initialize(opts={})
      super :pub, opts
    end
  end


  # SubSockets are the counterpart of PubSockets (PUB/SUB)
  class SubSocket < Socket
    include ReadableSocket

    def initialize(opts={})
      super :sub, opts
    end

    def subscribe(topic)
      rc = self.raw_socket.setsockopt(::ZMQ::SUBSCRIBE, topic)
      check_rc!(rc, err_label: 'subscribe', err_msg: "couldn't set subscribe")
    end

    def unsubscribe(topic)
      rc = self.raw_socket.setsockopt(::ZMQ::UNSUBSCRIBE, topic)
      check_rc!(rc, err_label: 'subscribe', err_msg: "couldn't set unsubscribe")
    end
  end

end
