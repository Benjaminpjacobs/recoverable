module Recoverable
  class RetryCountExceeded < StandardError
    def initialize(error)
      super error
    end
  end
end