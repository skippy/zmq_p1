require 'ostruct'

class ZMQP1
  class Util

    class << self
      def required_arg
        method = caller_locations(1,1)[0].label
        raise ArgumentError,
          "A required keyword argument was not specified when calling '#{method}'"
      end


      # inspired from: http://stackoverflow.com/questions/7093992/how-to-have-an-inherited-callback-in-ruby-that-is-triggered-after-the-child-clas
      def after_loaded child = nil, &blk
        end_count = 0
        set_trace_func(lambda do |event, file, line, id, binding, classname|
          if event == 'class' || event == 'module'
            end_count += 1
          end
          end_count -= 1 if event == 'end'
          if end_count < 0
            set_trace_func nil
            blk.call child
          end
        end)
      end
    end

  end
end


class OpenStruct
  unless defined?(:to_hash)
    alias_method :to_hash, :to_h
  end
end

# taken from ActiveSupport;
class NilClass
  def try(*args)
    nil
  end
end

class Object
  def try(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      __send__(*a, &b)
    end
  end
end

