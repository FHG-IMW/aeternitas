# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aeternitas/version'

Gem::Specification.new do |spec|
  spec.name          = "aeternitas"
  spec.version       = Aeternitas::VERSION
  spec.authors       = ["Michael Prilop", "Max Kießling", "Robert Therbach"]
  spec.email         = ["max@kopfueber.org"]

  spec.summary       = %q{my summary}
  spec.description   = %q{My Description}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 5.0"
  spec.add_dependency "redis"
  spec.add_dependency "connection_pool"
  spec.add_dependency "aasm"
  spec.add_dependency "sidekiq"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "database_cleaner", "~> 1.5"
  spec.add_development_dependency "memfs"
end
