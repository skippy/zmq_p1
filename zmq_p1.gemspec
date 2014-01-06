require File.expand_path("../lib/zmq_p1/version", __FILE__)

Gem::Specification.new do |s|
  s.name          = "zmq_p1"
  s.version       = ZMQP1::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Adam Greene"]
  s.email         = ["adam.greene@gmail.com"]

  s.summary       = %q{TODO: Write a gem summary}
  s.homepage      = "http://github.com/skippy/zmq_p1"
  s.license       = "MIT"

  # s.files         = `git ls-files`.split($/)
  s.files         = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  # s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]


  # s.executables = ["newgem"]

  s.add_dependency "msgpack", "~> 0.5.8"
  # s.add_dependency "ffi-rzmq"
  s.add_development_dependency "bundler", "~>1.3.5"
  s.add_development_dependency "rspec", "~>3.0.0.beta1"
  s.add_development_dependency "rake"
end

