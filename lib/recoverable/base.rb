module Recoverable
  def recover(method_name, tries: 1, on: StandardError, wait: nil, wait_method: nil,custom_handler: nil, throw: RetryCountExceeded)
    recoverable = [on].flatten
    proxy       = create_proxy(method_name: method_name, tries: tries, recoverable: recoverable, wait: wait, wait_method: wait_method, custom_handler: custom_handler, throw: throw)
    self.prepend proxy
  end

  def create_proxy(method_name:, tries:, recoverable:, wait:, wait_method:, custom_handler:, throw:)
    Module.new do
      define_method(method_name) do |*args|
        retries = tries
        begin
          super *args
        rescue *recoverable => error
          self.class.handle_wait(wait, wait_method) if wait
          retry        if (retries -= 1) > 0
          self.class.handle_exception(instance: self, custom_handler: custom_handler, args: args, error: error, throw: throw)
        end
      end
    end
  end

  def handle_wait(wait, wait_method)
    if wait_method
      wait_method.call(wait)
    else
      Defaults.wait(wait)
    end
  end

  def handle_exception(instance:, custom_handler:, args:, error:, throw: )
    raise throw.new(error) unless custom_handler
    req_params = retrieve_required_parameters(instance, custom_handler)

    return instance.send(custom_handler) if req_params.empty?
    instance.send(custom_handler, *args, { error: error })
  end

  def retrieve_required_parameters(instance, custom_handler)
    unbound_method = instance.class.instance_method(custom_handler)
    unbound_method.parameters.map{|p| p[1] if p[0] == :keyreq }.compact
  end
end


