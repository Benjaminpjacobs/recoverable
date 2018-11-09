require 'spec_helper'
RSpec.describe Recoverable do
  let!(:instance) { self.class::TestClass.new }
  subject{ instance.bar }
  context "most basic defaults" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2

      def bar; baz; end
      def baz; end

    end

    it "rescues on standard error and does not sleep" do
      expect_any_instance_of(Kernel).to receive(:sleep).never
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(StandardError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end

    it "rescues from inheritors of standard error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end
  end

  context "configuring a specific error to resuce" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: CustomError

      def bar; baz; end
      def baz; end

    end

    it "rescues from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end

    it "does not rescue from different raised error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(UnrecoveredError)
      expect{ subject }.to raise_error(UnrecoveredError)
    end

    it "does not rescue from standard error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(StandardError)
      expect{ subject }.to raise_error(StandardError)
    end
  end

  context "configuring multiple specific errors to resuce" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: [CustomError, AlternateCustomError]

      def bar; baz; end
      def baz; end

    end

    it "rescues from error A" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end

    it "rescues from error B" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(AlternateCustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end

    it "does not rescue from different raised error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(UnrecoveredError)
      expect{ subject }.to raise_error(UnrecoveredError)
    end

    it "does not rescue from standard error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(StandardError)
      expect{ subject }.to raise_error(StandardError)
    end
  end

  context "configuring sleep time" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: CustomError, sleep: 3

      def bar; baz; end
      def baz; end

    end

    it "sleeps for configured time" do
      expect_any_instance_of(Kernel).to receive(:sleep).with(3).exactly(2).times
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
    end
  end

  context "configure custom exception" do
    class self::TestClass
      class TestCustomExecption < StandardError; end
      extend Recoverable
      recover :bar, tries: 2, on: CustomError, custom_exception: TestCustomExecption

      def bar; baz; end
      def baz; end

    end

    it "responds from error with custom exception" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect{ subject }.to raise_error(self.class::TestClass::TestCustomExecption)
    end
  end


  context "configure custom error handler" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: CustomError, custom_handler: :handle_error

      def bar; baz; end
      def baz; end
      def handle_error
        "Handled"
      end

    end

    it "recovers from configured error by running handler method" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq("Handled")
    end
  end

  context "handler method utilizes returned error" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: CustomError, custom_handler: :handle_error

      def bar(arg:nil)
        baz
      end

      def baz; end

      def handle_error(error:)
        error.message
      end

    end

    subject { instance.bar}

    it "has access to the raised error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError.new("Custom Error!"))
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq("Custom Error!")
    end
  end

  context "handler method utilizes args" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: CustomError, custom_handler: :handle_error

      def bar(arg:nil)
        baz
      end

      def baz; end

      def handle_error(error:, arg:)
        arg
      end

    end

    subject { instance.bar(arg: "I'm a keyword Arg")}

    it "has access to the keyword args" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq("I'm a keyword Arg")
    end
  end

  context "handler method utilizes other instance private and public methods" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: CustomError, custom_handler: :handle_error

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

    subject { instance.bar}

    it "recovers from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq( "I'm a method call, I'm a private method call")
    end
  end

  context "handler method utilizes instance variables" do
    class self::TestClass
      extend Recoverable
      recover :bar, tries: 2, on: CustomError, custom_handler: :handle_error
      attr_reader :qux

      def initialize
        @qux = "I'm an instance variable"
      end

      def bar(arg:nil)
        baz
      end

      def baz; end

      def handle_error(error:, instance_variable: qux)
        "#{instance_variable}"
      end

    end

    subject { instance.bar}

    it "recovers from specific error" do
      allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
      expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
      expect(subject).to eq( "I'm an instance variable")
    end
  end
end