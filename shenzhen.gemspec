# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "shenzhen"

Gem::Specification.new do |s|
  s.name        = "shenzhen"
  s.authors     = ["Mattt Thompson"]
  s.email       = "m@mattt.me"
  s.homepage    = "http://github.com/mattt/shenzhen"
  s.version     = Shenzhen::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Shenzhen"
  s.description = "CLI for Building & Distributing iOS Apps (.ipa Files)"

  s.add_development_dependency "rspec", "~> 0.6.1"
  s.add_development_dependency "rake",  "~> 0.9.2"

  s.add_dependency "commander", "~> 4.1.2"
  s.add_dependency "json", "~> 1.7.3"
  s.add_dependency "faraday", "~> 0.8.0"
  s.add_dependency "faraday_middleware", "~> 0.8.7"

  s.files         = Dir["./**/*"].reject { |file| file =~ /\.\/(bin|log|pkg|script|spec|test|vendor)/ }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
