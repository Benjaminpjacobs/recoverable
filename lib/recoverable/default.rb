module Recoverable
  class Defaults
    @wait_method = Proc.new{ |int| Kernel.sleep int }
    class << self

      attr_accessor :wait_method

      def wait(int)
        @wait_method.call(int)
      end
    end
  end
end