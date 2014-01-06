require 'logger'
require 'ffi-rzmq'

class ZMQP1
  require 'zmq_p1/util'
  require 'zmq_p1/socket'
  require 'zmq_p1/message'
  require 'zmq_p1/rpc'

  class << self
    attr_accessor :logger   # Thread-safe logger class

    # Obtain a ZMQ context; this is thread safe!
    def context
      @context ||= ::ZMQ::Context.new
    end


    def terminate
      ZMQP1.logger.debug{ "Stopping ZMQP1.context" }
      context.terminate
    end


    #FIXME: figure out way to cleanly shut down broker
    def broker(frontend_address, backend_address)
      # Socket facing clients
      frontend = ZMQP1::RouterSocket.new(:identity => "[ZMQP1::Broker] Router: From #{frontend_address}")
      frontend.bind(frontend_address)

      # Socket facing services
      backend = ZMQP1::DealerSocket.new(:identity => "[ZMQP1::Broker] Dealer: To #{backend_address}")
      backend.bind(backend_address)

      at_exit do
        frontend.close
        backend.close
      end
      ZMQP1.logger.debug{ "Broker setup: #{frontend_address} -> #{backend_address}"}
      # Start built-in proxy; this is a ZMQ::Queue that acts as a broker to the outside system
      # TODO: figure out how to terminate this proxy; it hangs up the system
      ::ZMQ::Proxy.new(frontend.raw_socket, backend.raw_socket)
    end
  end

  at_exit{ ZMQP1.terminate }

end

# Configure default systemwide settings
ZMQP1.logger = Logger.new(STDERR)
