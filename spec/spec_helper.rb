require 'bundler/setup'
require 'simplecov'
require 'pry'

SimpleCov.start do
  add_filter '/spec'
end

require 'recoverable'
require 'mocks/test_errors'
require 'factory_bot'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

end

RSpec::Expectations.configuration.on_potential_false_positives = :nothing