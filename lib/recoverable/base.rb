module Recoverable
  def recover(method_name, times, on: [StandardError], sleep: nil, custom_handler: nil, custom_exception: RetryCountExceeded)
    recoverable = Array.wrap(on)
    proxy       = create_proxy(method_name: method_name, times: times, recoverable: recoverable, sleep: sleep, custom_handler: custom_handler, custom_exception: custom_exception)
    self.prepend proxy
  end

  def create_proxy(method_name:, times:, recoverable:, sleep:, custom_handler:, custom_exception:)
    Module.new do
      define_method(method_name) do |*args|
        retries = times.dup
        begin
          super *args
        rescue *recoverable => error
          begin
            sleep(sleep) if sleep
            retries.next && retry
          rescue StopIteration
              self.class.handle_exception(instance: self, custom_handler: custom_handler, args: args, error: error, custom_exception: custom_exception)
          end
        end
      end
    end
  end

  def handle_exception(instance:, custom_handler:, args:, error:, custom_exception: )
    raise custom_exception.new(error) unless custom_handler

    unbound      = instance.class.instance_method(custom_handler)
    req_params   = unbound.parameters.map{|p| p[1] if p[0] == :keyreq }.compact

    if req_params.empty?
      return instance.send(custom_handler) 
    else
      custom_handler_args = fetch_handler_args(args, instance, req_params, error)
      instance.send(custom_handler, custom_handler_args)
    end
  end

  def fetch_handler_args(args, instance, req_params, error)
    custom_handler_args = {error: error}
    local_args   = args.map(&:to_a).flatten(1).to_h
    ivs          = instance.instance_values.keys.map(&:to_sym)

    req_params.each do |key|
      custom_handler_args[key] ||= instance.send(:eval, key.to_s)  if (ivs + instance.send(:public_methods) + instance.send(:local_variables)).include?(key)
      custom_handler_args[key] ||= local_args[key] if local_args.keys.include?(key)
    end
    custom_handler_args
  end

end


