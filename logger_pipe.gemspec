# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'logger_pipe/version'

Gem::Specification.new do |spec|
  spec.name          = "logger_pipe"
  spec.version       = LoggerPipe::VERSION
  spec.authors       = ["akima"]
  spec.email         = ["akm2000@gmail.com"]
  spec.description   = %q{logger_pipe helps to connect child process STDOUT to Logger on realtime}
  spec.summary       = %q{logger_pipe helps to connect child process STDOUT to Logger on realtime}
  spec.homepage      = "https://github.com/groovenauts/logger_pipe"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
