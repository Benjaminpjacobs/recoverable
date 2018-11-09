require 'spec_helper'
RSpec.describe Recoverable do
  let!(:instance) { self.class::TestClass.new }
  subject{ instance.bar }
  context "passing no errors" do
    class self::TestClass
      extend Recoverable
      recover :bar, times: 2

      def bar; baz; end
      def baz; end

    end

    it "defaults to standard error and no sleep" do
      expect_any_instance_of(Kernel).to receive(:sleep).never
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(StandardError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end

    it "recovers from inheritors of standard error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end

  end

  context "passing specific errors" do
    class self::TestClass
      extend Recoverable
      recover :bar, times: 2, on: CustomError

      def bar; baz; end
      def baz; end

    end

    it "recovers from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end

    it "does not recover from different raised error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(UnrecoveredError)
      expect{ subject }.to raise_error(UnrecoveredError)
    end

    it "does not recover from standard error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(StandardError)
      expect{ subject }.to raise_error(StandardError)
    end

  end

  context "passing specific sleep" do
    class self::TestClass
      extend Recoverable
      recover :bar, times: 2, on: CustomError, sleep: 3

      def bar; baz; end
      def baz; end

    end

    it "recovers from specific error" do
      expect_any_instance_of(Kernel).to receive(:sleep).with(3).exactly(2).times
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end
  end

  context "passing custom error handler" do
    class self::TestClass
      extend Recoverable
      recover :bar, times: 2, on: CustomError, custom_handler: :handle_error

      def bar; baz; end
      def baz; end
      def handle_error
        "Handled"
      end

    end

    it "recovers from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq("Handled")
    end
  end
  
  context "passing custom error handler with error message" do
    class self::TestClass
      extend Recoverable
      recover :bar, times: 2, on: CustomError, custom_handler: :handle_error

      def bar(arg:nil)
        baz
      end

      def baz; end

      def handle_error(error:)
        error.message
      end

    end

    subject { instance.bar(arg: "I'm a keyword Arg")}

    it "recovers from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError.new("Custom Error!"))
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq("Custom Error!")
    end
  end

  context "passing custom error handler with arg" do
    class self::TestClass
      extend Recoverable
      recover :bar, times: 2, on: CustomError, custom_handler: :handle_error

      def bar(arg:nil)
        baz
      end

      def baz; end

      def handle_error(error:, arg:)
        arg
      end

    end

    subject { instance.bar(arg: "I'm a keyword Arg")}

    it "recovers from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq("I'm a keyword Arg")
    end
  end

  context "passing custom error handler with a method call" do
    class self::TestClass
      extend Recoverable
      recover :bar, times: 2, on: CustomError, custom_handler: :handle_error

      def bar(arg:nil)
        baz
      end

      def baz; end

      def handle_error(error:)
        "#{method_call}, #{private_method_call}"
      end

      def method_call
        "I'm a method call"
      end
      private

      def private_method_call
        "I'm a private method call"
      end

    end

    subject { instance.bar(arg: "I'm a keyword Arg")}

    it "recovers from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq( "I'm a method call, I'm a private method call")
    end
  end
end