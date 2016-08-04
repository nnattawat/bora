require 'bora/cfn/stack'

class Bora
  module Resolver
    class Cfn
      StackDoesNotExist = Class.new(StandardError)
      ValueNotFound = Class.new(StandardError)
      InvalidParameter = Class.new(StandardError)

      def initialize
        @stack_cache = {}
      end

      def resolve(uri)
        stack_name = uri.host
        section, name = uri.path.split("/").reject(&:empty?)
        if !stack_name || !section || !name || section != 'outputs'
          raise InvalidParameter, "Invalid parameter substitution: #{uri}"
        end

        stack = @stack_cache[stack_name] || Bora::Cfn::Stack.new(stack_name)
        if !stack.exists?
          raise StackDoesNotExist, "Output #{name} not found in stack #{stack_name} as the stack does not exist"
        end

        outputs = stack.outputs || []
        matching_output = outputs.find { |output| output.key == name }
        if !matching_output
          raise ValueNotFound, "Output #{name} not found in stack #{stack_name}"
        end

        matching_output.value
      end
    end
  end
end
