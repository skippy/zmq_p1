require 'thread'
#
# Design:
#  - every thread MUST have its own zmq socket
#  - external sources connect to a queue, which distribute to local workers
# TODOS:
#  - when error occurs on worker, kill it and fire up a new thread
#  - retry on failure?
#  - HWM handling; what if the queue starts to get really large?!
class ZMQP1
  module RPC
    class Server
      attr_reader :num_workers, :address, :verbose

      # ZMQP1::RPC::Server.start! do |msg|
      #   # work to go in here; make sure whatever happens in here is thread safe!
      #   # a ZMQP1::Message is passed in to do with as you please
      # end
      class << self
        def start!(opts={}, &block)
          @instance = self.new(opts, &block).start!
        end


        def stop!
          @instance.try(:shutdown!)
        end
      end


      at_exit do
        ZMQP1::RPC::Server.stop!
      end


      def initialize(opts={}, &block)
        opts = {
                 :server => {},
                 :client => {}
               }.merge(opts)
        @num_workers = opts[:server].fetch(:num_workers, 5)
        @address     = opts[:address]
        @verbose     = opts[:verbose]
        @preload     = opts[:server][:preload]
        @block_of_work  = block
      end


      def verbose?
        !!self.verbose
      end


      # def start!(&block)
      def start!
        shutdown! if @running

        @running = true
        @preload.try(:call)
        @worker_threads = []
        self.num_workers.times{ register_worker(&@block_of_work) }
        ZMQP1.broker(self.address, 'inproc://workers')
      end


      def running?
        !!@running
      end


      def shutdown!
        @running = false
        #FIXME: have join terminate after a certain amount of time
        @worker_threads.collect(&:join)
      end


      def worker_routine(&block)
        #NOTE: make sure nothing from self gets modified!
        #make sure this stays in the same thread as to where it is used!
        dispatch_socket = ZMQP1::ResponseSocket.new(:identity => "local_worker_#{Thread.current.object_id}")
        dispatch_socket.connect("inproc://workers")
        begin
          while running? do
            msg = dispatch_socket.read
            if !msg.pending?
              #FIXME: probably respond with an error msg
            else
              begin
                # response = klass.send(msg.message['n'], *msg.message['a'])
                # response = klass.rpc_process
                response = block.call
                if verbose?
                  ZMQP1.logger.debug{ "Processed #{msg.message['n']}(#{msg.message['a'].join(',')}) => #{response.inspect} by worker #{Thread.current.object_id}"}
                end
                msg.success!(response)
              rescue => e
                msg.erred!(e)
              end
            end
            dispatch_socket.write(msg)
          end
        rescue => e
          #FIXME: handle socket errors here
          #FIXME: retry or shutdown and spawn a new thread?
puts "FAILED: #{e.message}"
puts e.backtrace.join("\n")
          #handle socket errors here
        end
      ensure
        restart_worker(&block)
      end
      private :worker_routine


      def register_worker(&block)
        @worker_threads << Thread.new{ worker_routine(&block) }
      end
      private :register_worker


      def restart_worker(&block)
        ZMQP1.logger.debug{ "Worker #{Thread.current.object_id} is stopping" }
        dispatch_socket.try(:close)
        @worker_threads.delete(Thread.current)
        register_worker(&block)
      end
      private :restart_worker

    end #Server
  end
end
