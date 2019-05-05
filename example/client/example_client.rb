require 'lambda_worker'

class ExampleWorker < LambdaWorker::Base
  configure do |config|
    config.profile = 'default'
    config.region = 'ap-northeast-1'
  end

  function :do_something
end

response = ExampleWorker.sync.do_something(a: 'A', b: 10)

puts "'A' * 10 = '#{response.payload['result']}'"
