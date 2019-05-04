require 'aws-sdk-lambda'
require 'active_support/core_ext/string'

module LambdaWorker
  class Base
    Config = Struct.new('Config',
                        :aws_access_key_id,
                        :aws_secret_access_key,
                        :region,
                        :profile,
                        :base_name,
                        :stage)

    def self.configure
      yield config
    end

    def self.function(name)
      define_singleton_method(name) do |**args|
        client.invoke(
          function_name: function_name(name),
          payload: args.to_json
        )
      end

      define_singleton_method("#{name}_async") do |**args|
        client.invoke_async(
          function_name: function_name(name),
          invoke_args: args.to_json
        )
      end
    end

    def self.function_name(name)
      "#{config.base_name}-#{config.stage}-#{name}"
    end

    def self.config
      unless @config
        @config = Config.new
        @config.base_name = self.to_s.underscore.gsub('_', '-')
        @config.stage = 'development'
      end
      @config
    end

    def self.client
      options = {
        region: config.region
      }

      case
      when config.profile
        options[:profile] = config.profile
      when config.aws_access_key_id && config.aws_secret_access_key
        options[:credentials] = Aws::Credentials.new(config.aws_access_key_id, config.aws_secret_access_key)
      end

      Aws::Lambda::Client.new(options)
    end
  end
end
