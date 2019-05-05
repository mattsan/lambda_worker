class TestWorker < LambdaWorker::Base
  configure do |config|
    config.stage = 'test'
    config.region = 'ap-northeast-1'
  end

  function :do_something
end

RSpec.describe LambdaWorker do
  it 'has a version number' do
    expect(LambdaWorker::VERSION).not_to be nil
  end

  describe 'configurations' do
    describe 'stage' do
      describe 'default' do
        it { expect(TestWorker.config.stage).to eq('test') }
        it { expect(TestWorker.function_name('some_function')).to eq('test-worker-test-some_function') }
      end

      describe 'configure by a method' do
        before do
          class TestWorker
            configure do |config|
              config.stage = 'staging'
            end
          end
        end

        it { expect(TestWorker.config.stage).to eq('staging') }
        it { expect(TestWorker.function_name('some_function')).to eq('test-worker-staging-some_function') }
      end

      describe 'configure dynamically' do
        before do
          TestWorker.config.stage = 'production'
        end

        it { expect(TestWorker.config.stage).to eq('production') }
        it { expect(TestWorker.function_name('some_function')).to eq('test-worker-production-some_function') }
      end
    end
  end

  describe 'calling functions' do
    let(:lambda_client) { instance_double(Aws::Lambda::Client) }
    let(:client_params) { {region: 'ap-northeast-1'} }

    before do
      allow(Aws::Lambda::Client).to receive(:new)
        .with(client_params)
        .and_return(lambda_client)
    end

    describe 'synchronously' do
      let(:invocation_request) do
        {
          function_name: 'test-worker-test-do_something',
          payload: {a: [1, 2, 3], b: [4, 5, 6]}.to_json
        }
      end
      let(:response_payload) { {c: [3, 2, 1], d: [6, 5, 4]} }
      let(:response_params) { {status_code: 200, payload: StringIO.new(response_payload.to_json)} }
      let(:invocation_response) { Aws::Lambda::Types::InvocationResponse.new(response_params) }

      before do
        allow(lambda_client).to receive(:invoke)
          .with(invocation_request)
          .and_return(invocation_response)
      end

      it '.do_something' do
        response = TestWorker.sync.do_something(a: [1, 2, 3], b: [4, 5, 6])
        expect(response.status_code).to eq(200)
        expect(response.payload).to eq('c' => [3, 2, 1], 'd' => [6, 5, 4])
      end
    end

    describe 'asynchronously' do
      let(:invocation_request) do
        {
          function_name: 'test-worker-test-do_something',
          invoke_args: {a: [1, 2, 3], b: [4, 5, 6]}.to_json
        }
      end
      let(:invocation_response) { Aws::Lambda::Types::InvokeAsyncResponse.new(status: 202) }

      before do
        allow(lambda_client).to receive(:invoke_async)
          .with(invocation_request)
          .and_return(invocation_response)
      end

      it '.do_something' do
        response = TestWorker.async.do_something(a: [1, 2, 3], b: [4, 5, 6])
        expect(response.status_code).to eq(202)
      end
    end
  end
end
