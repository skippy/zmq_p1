# ZMQP1

[![Code Climate](https://codeclimate.com/github/skippy/zmq_p1.png)](https://codeclimate.com/github/skippy/zmq_p1)


Zero MQ Plus 1: a not so smart play on words, this being an abstraction layer on top of the excellent ZMQ library.

This is a general purpose library built upon ZMQ, providing a more OO and ruby-like experience.  It wraps best-practices around error handling, logging, retries, and timeouts.  It is also a collection of commonly used network patterns like client/servers and threaded proxies.

Other additions:
* A light-weight RPC library
* examples for:
   * thrift layer
   * pushing and receiving data from RabbitMQ
   * pushing data to an HTTP endpoint
   * receiving data from an NGINX (http) endpoint
   * configuration examples for an HAProxy layer

## RPC
TODO

## Other Users
TODO


## Installation

Add this line to your application's Gemfile:

    gem 'zmq_p1'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install zmq_p1

## Usage

TODO: Write usage instructions here


### RPC usage

#### Client

add `extend ZMQP1::RPC` to any class.

Currently only class or singleton-level methods are supported for remote execution

```ruby
class Example
  extend ZMQP1::RPC

  def self.my_method
    'hello world'
  end
end
```

#### Server
 start up the remote server on the same host
run `bin/zmqp1 Example --require lib/example`

pass in the require path and the specific class/module to run under RPC, and you are all set!  Any singleton method on Example will now run through the remote server


#### Configurations

Here are the configurations available to the ruby code

```ruby
class Example
  extend ZMQP1::RPC

  rpc_configs do |conf|
    conf.address = 'tcp://10.0.0.1:5555'    # default: ipc:///tmp/example.ipc
    conf.verbose = true                     # default: false.  Prints out every msg sent and received by zmq
    conf.server do |s|
      s.num_workers = 5                     # default: 5
      s.preload = lambda{                   # run code before the woker threads are fired off
        require 'another/class'
        #change the state of something, such as
        Secure::FIPS.enable!
      }
    end
    conf.client do |c|
      c.retries = 3                         # default: 3
      c.timeout = 50                        # default: 50ms
      c.preload = lambda{}                  # run code before the client fires up.
    end
  end


  def self.my_method
    'hello world'
  end
end
```

To customize the configuration options, you can add them to the class or the commandline
`bin/zmqp1 --help`
`bin/zmqp1 --workers 5 --verbose --log_path /my/log/file.log --syslog --require /my/special/file.rb`




## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
