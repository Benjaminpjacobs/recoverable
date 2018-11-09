module Recoverable
  def recover(method_name, tries: 1, on: StandardError, sleep: nil, custom_handler: nil, custom_exception: RetryCountExceeded)
    recoverable = Array.wrap(on)
    proxy       = create_proxy(method_name: method_name, tries: tries, recoverable: recoverable, sleep: sleep, custom_handler: custom_handler, custom_exception: custom_exception)
    self.prepend proxy
  end

  def create_proxy(method_name:, tries:, recoverable:, sleep:, custom_handler:, custom_exception:)
    Module.new do
      define_method(method_name) do |*args|
        retries = tries
        begin
          super *args
        rescue *recoverable => error
          sleep(sleep) if sleep
          retry        if (retries -= 1) > 0
          self.class.handle_exception(instance: self, custom_handler: custom_handler, args: args, error: error, custom_exception: custom_exception)
        end
      end
    end
  end

  def handle_exception(instance:, custom_handler:, args:, error:, custom_exception: )
    raise custom_exception.new(error) unless custom_handler
    req_params = retrieve_required_parameters(instance, custom_handler)

    return instance.send(custom_handler) if req_params.empty?

    custom_handler_args = fetch_handler_args(args, instance, req_params, error)
    instance.send(custom_handler, custom_handler_args)
  end

  def retrieve_required_parameters(instance, custom_handler)
    unbound_method = instance.class.instance_method(custom_handler)
    unbound_method.parameters.map{|p| p[1] if p[0] == :keyreq }.compact
  end

  def fetch_handler_args(args, instance, req_params, error)
    custom_handler_args = {error: error}
    local_args          = fetch_local_args(args)
    evaluateables       = evaluateable_keys_on(instance)
    generate_custom_handler_args(req_params: req_params, evaluateables: evaluateables, local_args: local_args, instance: instance, custom_handler_args: custom_handler_args)
  end

  def generate_custom_handler_args(req_params:, evaluateables:, local_args:, instance:, custom_handler_args:)
    req_params.each do |key|
      custom_handler_args[key]   = instance.send(:eval, key.to_s)  if evaluateables.include?(key)
      custom_handler_args[key] ||= local_args[key] if local_args.keys.include?(key)
    end

    custom_handler_args
  end

  def fetch_instance_variables(instance)
    instance.instance_values.keys.map(&:to_sym)
  end

  def fetch_local_args(args)
    args.map(&:to_a).flatten(1).to_h
  end

  def evaluateable_keys_on(instance)
    fetch_instance_variables(instance) +
    instance.send(:public_methods) +
    instance.send(:local_variables)
  end
  
end


