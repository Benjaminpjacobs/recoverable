require_relative "lib/recoverable/version"

Gem::Specification.new do |s|
  s.name        = "recoverable"
  s.version     = Recoverable::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ben Jacobs"]
  s.email       = ["benjaminpjacobs@gmail.com"]
  s.summary     = %q{Class Level retry DSL for ruby}
  s.description = %q{Class Level retry DSL for ruby}

  s.metadata['allowed_push_host'] = 'https://rubygems.org'

  s.files         = Dir["MIT-LICENSE", "CHANGELOG.md", "README.md", "lib/**/*"]
  s.test_files    = Dir["spec/**/*"]
  s.require_paths = ["lib"]

  s.required_ruby_version = '>= 2.3'

  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rspec', '~> 3.0'
end
