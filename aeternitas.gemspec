# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aeternitas/version'

Gem::Specification.new do |spec|
  spec.name          = 'aeternitas'
  spec.version       = Aeternitas::VERSION
  spec.authors       = ['Michael Prilop', 'Max Kießling', 'Robert Terbach']
  spec.email         = ['max@kopfueber.org', 'michael.prilop@imw.fraunhofer.de']

  spec.summary       = "æternitas - A ruby gem for continuous source retrieval and data integration"
  spec.description   = <<-EOF
    Æternitas provides means to regularly 'poll' resources (i.e. a website, twitter feed or API) and to permanently
    store retrieved results. By default æternitas avoids putting too much load on external servers and stores raw
    results as compressed files on disk. It can be configured to a wide variety of polling strategies (e.g. frequencies,
    cooldown periods, ignoring exceptions, deactivating resources, ...)."
  EOF
  spec.homepage      = "https://github.com/FHG-IMW/aeternitas"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '~> 5.0'
  spec.add_dependency 'redis'
  spec.add_dependency 'connection_pool'
  spec.add_dependency 'aasm'
  spec.add_dependency 'sidekiq', '> 4'
  spec.add_dependency 'sidekiq-unique-jobs', '~> 5.0'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'database_cleaner', '~> 1.5'
  spec.add_development_dependency 'memfs'
  spec.add_development_dependency 'rspec-sidekiq'
  spec.add_development_dependency 'mock_redis'
end
