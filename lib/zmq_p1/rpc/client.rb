require 'thread'
# Design:
#  - every thread MUST have its own zmq socket
#  - every local thread socket pushes to a broker, which then coordinates out to external source
#  - designed to be able to work with any ZMQ topology; that includes connecting to RabbitMQ!
# TODO:
#  - HWM handling; right now we set to linger == 0, but that is just for the client sockets;
#    what about the broker?
#  - what is the fallback if the end point is not available?  do we queue, block, or throw away?
class ZMQP1
  module RPC
    class Client
      extend Forwardable

      attr_reader :socket

      class << self
        def instance(label, opts)
          Thread.current["#{label}_zmq_client"] ||= self.new(opts)
        end
      end


      def initialize(opts={})
        raise ArgumentError, "Address for setting up RPC must be set!" unless opts[:address]
        @socket = ZMQP1::RequestSocket.new(opts.merge(:identity => "local_client_#{object_id}"))
        @socket.connect(opts[:address])
      end


      def_delegators :@socket, :identity, :read, :write, :<<, :linger, :read_message

    end #Client
  end
end
