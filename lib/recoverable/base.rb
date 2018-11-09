module Recoverable
  RetryCountExceeded = Class.new(StandardError)

  def recover(method_name, times, on: [StandardError], sleep: nil, handler: nil)
    recoverable = Array.wrap(on)
    proxy = create_proxy(method_name, times, recoverable, sleep, handler)
    self.prepend proxy
  end

  def create_proxy(method_name, times, recoverable, sleep, handler)
    local_context = self.send(:binding)
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
            if handler
              handler_args = {}
              unbound     = self.class.instance_method(handler)
              req_params  = unbound.parameters.map{|p| p[1] if p[0] == :keyreq }.compact

              return send(handler) if req_params.empty?
              local_args = args.map(&:to_a).flatten(1).to_h
              ivs        = instance_values.keys.map(&:to_sym)

              req_params.each do |key|
                handler_args[key] ||= eval(key.to_s)  if (ivs + public_methods + local_variables).include?(key)
                handler_args[key] ||= local_args[key] if local_args.keys.include?(key)
              end
              binding.pry
              send(handler, handler_args)
            else
              raise RetryCountExceeded, [error.class, error.message]
            end
          end
        end
      end
    end
  end
  class RestryableError < StandardError
    attr_reader :binding
    def initialize(binding)
      @binding = binding
      super
    end
  end
end


