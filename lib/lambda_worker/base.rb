require 'aws-sdk-lambda'
require 'active_support/core_ext/string'

module LambdaWorker
  class Base
    Config =
      Struct.new('Config',
                 :aws_access_key_id,
                 :aws_secret_access_key,
                 :region,
                 :profile,
                 :base_name,
                 :stage)

    SyncResponse =
      Struct.new('SyncResponse',
                 :status_code,
                 :function_error,
                 :log_result,
                 :payload,
                 :executed_version)

    AsyncResponse =
      Struct.new('AsyncResponse',
                 :status_code)

    def self.configure
      yield config
    end

    def self.function(name)
      define_singleton_method(name) do |**args|
        response = client.invoke(
          function_name: function_name(name),
          payload: args.to_json
        )

        SyncResponse.new(
          response.status_code,
          response.function_error,
          response.log_result,
          JSON.parse(response.payload.read),
          response.executed_version
        )
      end

      define_singleton_method("#{name}_async") do |**args|
        response = client.invoke_async(
          function_name: function_name(name),
          invoke_args: args.to_json
        )

        AsyncResponse.new(
          response.status
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
