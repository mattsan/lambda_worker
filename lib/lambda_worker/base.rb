require 'aws-sdk-lambda'
require 'active_support/core_ext/string'

module LambdaWorker
  class Config
    attr_accessor :aws_access_key_id,
                  :aws_secret_access_key,
                  :region,
                  :profile,
                  :base_name,
                  :stage
  end

  class SyncResponse
    attr_reader :status_code,
                :function_error,
                :log_result,
                :payload,
                :executed_version

    def initialize(status_code, function_error, log_result, payload, executed_version)
      @status_code = status_code
      @function_error = function_error
      @log_result = log_result
      @payload = payload
      @executed_version = executed_version
    end
  end

  class AsyncResponse
    attr_reader :status_code

    def initialize(status_code)
      @status_code = status_code
    end
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
        @config.base_name = to_s.underscore.tr('_', '-')
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

    def invoke(function_name, args)
      response = client.invoke(function_name: function_name, payload: args.to_json)

      SyncResponse.new(
        response.status_code,
        response.function_error,
        response.log_result,
        JSON.parse(response.payload.read),
        response.executed_version
      )
    end

    def invoke_async(function_name, args)
      response = client.invoke_async(function_name: function_name, invoke_args: args.to_json)

      AsyncResponse.new(
        response.status
      )
    end

    private

    def client
      @client ||= Aws::Lambda::Client.new(options)
    end

    def config
      self.class.config
    end

    def options
      result = {region: config.region}
      result[:profile] = config.profile if config.profile
      result[:credentials] = credentials if config.aws_access_key_id && config.aws_secret_access_key
      result
    end

    def credentials
      Aws::Credentials.new(config.aws_access_key_id, config.aws_secret_access_key)
    end
  end
end
