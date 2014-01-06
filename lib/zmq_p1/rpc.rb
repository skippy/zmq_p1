require 'set'
require 'ostruct'

class ZMQP1
  # when ZMQP1::RPC is included, it allows the class to
  # have class-level public methods be called remotely
  # Design
  #
  # TODOs:
  #  - add metrics for every remote procedure call
  #  - auto_start?
  #  - auto-discover?
  #  - what happens if the server is not available?
  module RPC
    require 'zmq_p1/rpc/client'
    require 'zmq_p1/rpc/server'

    class << self
      class BlockNotAllowedError < StandardError; end
      def redirect_methods_to_remote(klass, allowed_methods)
        allowed_methods.each do |method_name|
          klass.class_eval( <<-end_eval, __FILE__, __LINE__ + 1)
            class << self
              alias_method_chain(:#{method_name}, :zmqp1_rpc) do |target, punctuation|
                class_eval( <<-inner_eval, __FILE__, __LINE__ + 1)
                  def \#{target}_with_zmqp1_rpc\#{punctuation}(*args)
                    raise BlockNotAllowedError, "Cannot pass block to rpc'ed version of \#{target}" if block_given?
                    send(:rpc_send, :#{method_name}, *args) do
                      \#{target}_without_zmqp1_rpc\#{punctuation}(*args)
                    end
                  end
                inner_eval
              end
            end
          end_eval
        end
      end
    end


    def self.extended(base)
      ZMQP1::Util.after_loaded do
        rpc_setup!
      end
    end


    # TODOs:
    #  - auto_discover ?
    #  - auto_start ?
    def rpc_configs
      @rpc_enabled = true
      @rpc_configs = OpenStruct.new(
        :address        => rpc_default_path,
        :verbose        => false,
        :server         => OpenStruct.new(
                             :preload => nil,
                             :num_workers => 5
                           ),
        :client         => OpenStruct.new(
                             :preload => nil,
                             :retries => 3,
                             :timeout => 50 #ms
                           )
      )
      yield @rpc_configs
      @rpc_configs.freeze
    end


    def rpc_enabled?
      !!@rpc_enabled
    end


    def start_rpc_server!
      # ZMQP1::RPC::Client.stop_broker!
      @rpc_server_mode = true
      klass = self
      raise ArgumentError, "#{klass} (#{klass.class}) is not setup for RPC" unless klass.rpc_enabled?
      ZMQP1::RPC::Server.start!(klass, @rpc_configs) do |msg|
        #run msg after we
        method_name, args = msg.message
        klass.send(method_name, *args)
      end
    end


    def rpc_in_server_mode?
      !!@rpc_server_mode
    end
    protected :rpc_in_server_mode?


    #FIXME: currently if the server is not up, this hangs.  Because this is triggered on a bunch
    # of background celluloid threads, it hangs them as well.
    # should throw an exception after a certain amount of time
    def rpc_send(method_name, *args, &block)
      return yield if rpc_in_server_mode? || rpc_enabled?
      begin
        rpc_client << [method_name, args]
        response = rpc_client.read
      rescue => e
        #FIXME: error handling as an error occured at the transport layer
      end
      if response.erred?
        #will have response.message = {:em => 'error msg', :eb => ['error backtrace'], :om => 'original message'}
      end
      response.message
    end
    protected :rpc_send


    def rpc_client
      return nil unless rpc_enabled?
      ZMQP1::RPC::Client.instance(self.name, @rpc_configs)
    end
    protected :rpc_client


    def rpc_allowed_method?(method)
      self.allowed_methods.include?(method.to_sym)
    end
    protected :rpc_allowed_method?


    def rpc_allowed_methods
      @rpc_allowed_methods ||= Set.new(self.public_methods - Object.methods - ZMQP1::RPC::ClassMethods.public_instance_methods)
    end
    protected :rpc_allowed_methods


    def rpc_verbose?
      @rpc_configs.verbose || false
    end
    private :rpc_verbose?


    def rpc_setup!
      return unless rpc_enabled?
      raise ArgumentError, "Address for setting up RPC must be set!" unless @rpc_configs.address
      @rpc_configs.client[:preload].call if @rpc_configs.client[:preload]
      ZMQP1::RPC.redirect_methods_to_remote(self, rpc_allowed_methods)
    end
    protected :rpc_setup!


    def rpc_default_path
      "ipc:///tmp/#{self.name.gsub(/(.)([A-Z])/,'\1_\2').gsub('::','').downcase}.ipc"
    end
    private :rpc_default_path


  end
end
