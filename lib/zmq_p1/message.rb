# Define our own basic wire protocol
class ZMQP1
  class Message
    require 'msgpack'

    PENDING_STATE = 0
    SUCCESS_STATE = 1
    ERROR_STATE   = -1

    attr_reader :headers, :message, :state

    class << self
      def load(raw)
        headers, state, message = MessagePack.unpack(raw)
        self.new(:message => message, :headers => headers, :state => state)
      end
    end


    # Create a new socket
    def initialize(message: ZMQP1::Util.required_arg, headers: {}, state: PENDING_STATE)
      @headers = headers
      @message = message
      @state   = state
    end


    def erred?
      self.state == ERROR_STATE
    end


    def successful?
      self.state == SUCCESS_STATE
    end


    def pending?
      self.state == PENDING_STATE
    end


    def success!(new_msg=nil)
      @state = SUCCESS_STATE
      @message = new_msg
    end


    def erred!(e)
      @state = ERROR_STATE
      if e.is_a?(Exception)
        @message = {:em => e.message, :eb => e.backtrace, :om => @message}
      else
        @message = {:em => e, :om => @message}
      end
    end


    def err_message
      return nil unless erred?
      @message.try(:[], :em) || @message
    end


    def err_backtrace
      return nil unless erred?
      @message.try(:[], :eb)
    end


    def err_orig_message
      return nil unless erred?
      @message.try(:[], :om)
    end


    def serialize
      [self.headers, self.state, self.message].to_msgpack
    end
  end #Message
end
