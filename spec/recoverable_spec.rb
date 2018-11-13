require 'spec_helper'
RSpec.describe Recoverable do
  context "Recover Directly on Class" do
    let!(:instance) { self.class::TestClass.new }
    subject{ instance.bar }
    context "With Basic Deafults" do
      class self::TestClass
        extend Recoverable
        recover :bar, tries: 2

        def bar; baz; end
        def baz; end

      end

      it "rescues on standard error and does not wait" do
        expect_any_instance_of(Kernel).to receive(:sleep).never
        allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(StandardError)
        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end

      it "rescues from inheritors of standard error" do
        allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end
    end

    context "Configured for a specific error to resuce" do
      class self::TestClass
        extend Recoverable
        recover :bar, tries: 2, on: CustomError

        def bar; baz; end
        def baz; end

      end

      it "rescues from that error" do
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

    context "Cofigured to rescue multiple specific errors" do
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

    context "Configured for custom wait time with defualt" do
      class self::TestClass
        extend Recoverable
        recover :bar, tries: 2, on: CustomError, wait: 3

        def bar; baz; end
        def baz; end

      end

      it "sleeps for configured time" do
        expect(Recoverable::Defaults.wait_method).to be_a(Proc)
        expect(Kernel).to receive(:sleep).with(3).exactly(2).times

        allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)

        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end
    end

    context "Configured for custom wait time with new default waiter method" do
      class self::TestClass
        extend Recoverable
        recover :bar, tries: 2, on: CustomError, wait: 3

        def bar; baz; end
        def baz; end

      end
      let(:custom_waiter) { Proc.new{|int| p "Called Custom Default with arg: #{int}"} }

      before(:each) do
        Recoverable::Defaults.wait_method = custom_waiter
      end

      it "custom waiter method for configured time" do
        expect(Recoverable::Defaults.wait_method).to eq(custom_waiter)
        expect(Recoverable::Defaults).to receive(:wait).with(3).exactly(2).times.and_call_original

        allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)

        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end
    end

    context "Configured for custom wait time with custom waiter method" do
      class self::TestClass
        extend Recoverable
        recover :bar, tries: 2, on: CustomError, wait: 3, wait_method: Proc.new{|int| p "Called Custom Waiter with arg: #{int}"}

        def bar; baz; end
        def baz; end

      end

      it "custom waiter method for configured time" do
        expect(Recoverable::Defaults).to receive(:wait).never
        allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)

        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end
    end

    context "Configured to raise custom exception" do
      class self::TestClass
        class TestCustomExecption < StandardError; end
        extend Recoverable
        recover :bar, tries: 2, on: CustomError, throw: TestCustomExecption

        def bar; baz; end
        def baz; end

      end

      it "rescues error and raises custom exception" do
        allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
        expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
        expect{ subject }.to raise_error(self.class::TestClass::TestCustomExecption)
      end
    end


    context "Configured to use a custom error handling method" do
      class self::TestClass
        extend Recoverable
        recover :bar, tries: 2, on: CustomError, custom_handler: :handle_error

        def bar; baz; end
        def baz; end
        def handle_error
          "Handled"
        end

      end

      it "recovers from configured error by running custom handler method" do
        allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
        expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
        expect(subject).to eq("Handled")
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

      context "handler method utilizes other private and public instance methods" do
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

        it "has access to private and public methods" do
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

          def handle_error(error:)
            "#{@qux}"
          end

        end

        subject { instance.bar}

        it "has access to instance variables" do
          allow_any_instance_of(self.class::TestClass).to receive(:baz).and_raise(CustomError)
          expect{ subject }.to_not raise_error(Recoverable::RetryCountExceeded)
          expect(subject).to eq( "I'm an instance variable")
        end
      end
    end

  end

  context "Recover Through Inheritence" do
    context 'Configuring recoverable on the parent class' do
      class self::TestParentClass
        extend Recoverable
        recover :bar, tries: 2
        def bar
          baz
        end

      end

      class self::TestChildClass < self::TestParentClass
        def bar
          super
        end

        def baz; end
      end

      let!(:instance) { self.class::TestChildClass.new }
      subject{ instance.bar }

      it "can recover an error through inheritence chain" do
        allow_any_instance_of(self.class::TestChildClass).to receive(:baz).and_raise(StandardError)
        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end

      context "recovered method overridden on the child class" do
        class self::TestParentClass
          extend Recoverable
          recover :bar, tries: 2

          def bar
            baz
          end
        end

        class self::TestChildClass < self::TestParentClass
          def bar
            baz
          end

          def baz; end
        end

        let!(:instance) { self.class::TestChildClass.new }
        subject{ instance.bar }

        it "will not recovers through inheritence chain" do
          allow_any_instance_of(self.class::TestChildClass).to receive(:baz).and_raise(StandardError)
          expect{ subject }.to raise_error(StandardError)
        end
      end
    end

    context 'Configuring recoverable on the parent class through multiple levels' do
      class self::TestParentClass
        extend Recoverable
        recover :bar, tries: 2
        def bar
          baz
        end

      end

      class self::TestChildClass < self::TestParentClass
        def baz; end
      end

      class self::TestSubChildClass < self::TestChildClass
        def bar
          super
        end
      end

      let!(:instance) { self.class::TestSubChildClass.new }
      subject{ instance.bar }

      it "can recover through the inheritence chain" do
        allow_any_instance_of(self.class::TestChildClass).to receive(:baz).and_raise(StandardError)
        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end
    end

    context 'Configuring recoverable on child class' do
      class self::TestParentClass
        def bar
          baz
        end
      end

      class self::TestChildClass < self::TestParentClass
        extend Recoverable
        recover :bar, tries: 2
        def baz; end
      end

      let!(:instance) { self.class::TestChildClass.new }
      subject{ instance.bar }

      it "can recover through inheritence chain" do
        allow_any_instance_of(self.class::TestChildClass).to receive(:baz).and_raise(StandardError)
        expect{ subject }.to raise_error(Recoverable::RetryCountExceeded)
      end
    end

    context "Handler Method" do
      context "Handler method defined on the parent class" do
        class self::TestParentClass
          extend Recoverable
          recover :bar, tries: 2, custom_handler: :handle_error

          def bar
            baz
          end

          def handle_error(error:)
            "Parent Handler!"
          end
        end

        class self::TestChildClass < self::TestParentClass
          def baz; end
        end

        let!(:instance) { self.class::TestChildClass.new }
        subject{ instance.bar }

        it "calls handler from the parent class" do
          allow_any_instance_of(self.class::TestChildClass).to receive(:baz).and_raise(StandardError)
          expect{ subject }.to_not raise_error(StandardError)
          expect(subject).to eq("Parent Handler!")
        end
      end

      context "Handler method defined on the child class" do
         class self::TestParentClass
          extend Recoverable
          recover :bar, tries: 2, custom_handler: :handle_error

          def bar
            baz
          end

          def handle_error(error:)
            "Parent Handler!"
          end

        end

        class self::TestChildClass < self::TestParentClass
          def baz; end

          def handle_error(error:)
            "Child Handler!"
          end
        end

        let!(:instance) { self.class::TestChildClass.new }
        subject{ instance.bar }

        it "calls handler from child class" do
          allow_any_instance_of(self.class::TestChildClass).to receive(:baz).and_raise(StandardError)
          expect{ subject }.to_not raise_error(StandardError)
          expect(subject).to eq("Child Handler!")
        end
      end
    end
  end
end