require 'aws-sdk-lambda'
require 'active_support/core_ext/string'

module LambdaWorker
  class Config < Struct.new(:aws_access_key_id,
                            :aws_secret_access_key,
                            :region,
                            :profile,
                            :base_name,
                            :stage)
  end

  class SyncResponse < Struct.new(:status_code,
                                  :function_error,
                                  :log_result,
                                  :payload,
                                  :executed_version)
  end

  class AsyncResponse < Struct.new(:status_code)
  end

  class Base
    def self.configure
      yield config
    end

    def self.function(name)
      func_name = function_name(name)
      define_method(name) do |**args|
        if @sync
          invoke(func_name, args)
        else
          invoke_async(func_name, args)
        end
      end
    end

    def self.function_name(name)
      [config.base_name, config.stage, name].join('-')
    end

    def self.config
      unless @config
        @config = Config.new
        @config.base_name = self.to_s.underscore.gsub('_', '-')
        @config.stage = 'development'
      end
      @config
    end

    def self.sync
      new(sync: true)
    end

    def self.async
      new(sync: false)
    end

    def initialize(sync:)
      @sync = sync
    end

    def config
      self.class.config
    end

    def client
      return @client if @client

      options = {
        region: config.region
      }

      case
      when config.profile
        options[:profile] = config.profile
      when config.aws_access_key_id && config.aws_secret_access_key
        options[:credentials] = Aws::Credentials.new(config.aws_access_key_id, config.aws_secret_access_key)
      end

      @client = Aws::Lambda::Client.new(options)
    end

    def invoke(function_name, args)
      response = client.invoke(
        function_name: function_name,
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

    def invoke_async(function_name, args)
      response = client.invoke_async(
        function_name: function_name,
        invoke_args: args.to_json
      )

      AsyncResponse.new(
        response.status
      )
    end
  end
end
