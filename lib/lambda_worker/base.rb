require 'aws-sdk-lambda'

module LambdaWorker
  class Base
    Config = Struct.new('Config', :aws_access_key_id, :aws_secret_access_key, :region, :profile)

    def self.configure
      yield config
    end

    def self.function(name)
      define_singleton_method(name) do |args|
        options = {
          function_name: name,
          invoke_args: args
        }

        client.invoke_async(options)
      end
    end

    def self.config
      @config ||= Config.new
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
