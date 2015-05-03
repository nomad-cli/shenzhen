# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "shenzhen/version"

Gem::Specification.new do |s|
  s.name        = "shenzhen"
  s.authors     = ["Mattt Thompson"]
  s.email       = "m@mattt.me"
  s.license     = "MIT"
  s.homepage    = "http://nomad-cli.com"
  s.version     = Shenzhen::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Shenzhen"
  s.description = "CLI for Building & Distributing iOS Apps (.ipa Files)"

  s.add_dependency "commander", "~> 4.3"
  s.add_dependency "highline", ">= 1.7.2"
  s.add_dependency "terminal-table", "~> 1.4.5"
  s.add_dependency "json", "~> 1.8"
  s.add_dependency "faraday", "~> 0.8.9"
  s.add_dependency "faraday_middleware", "~> 0.9"
  s.add_dependency "dotenv", ">= 0.7"
  s.add_dependency "aws-sdk", "~> 1.0"
  s.add_dependency "net-sftp", "~> 2.1.2"
  s.add_dependency "plist", "~> 3.1.0"
  s.add_dependency "rubyzip", "~> 1.1"
  s.add_dependency "security", "~> 0.1.3"

  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"

  s.files         = Dir["./**/*"].reject { |file| file =~ /\.\/(bin|log|pkg|script|spec|test|vendor)/ }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
