# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'temill/version'

Gem::Specification.new do |spec|
  spec.name          = "temill"
  spec.version       = Temill::VERSION
  spec.authors       = ["Yusuke Takeuchi"]
  spec.email         = ["v.takeuchi+gh@gmail.com"]

  spec.summary       = %q{Temill shows objects in embedded comments in source files.}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/YusukeTakeuchi/temill"
  spec.license       = "MIT"


  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.3'

  spec.add_dependency 'ruby_parser', '~> 3.8'

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency 'awesome_print', '~> 1.7'
end
