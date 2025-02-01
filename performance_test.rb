require 'rspec-benchmark'
require_relative 'task-1'

RSpec.configure do |config|
  config.include RSpec::Benchmark::Matchers
end

describe 'Task-1 Performance' do
  describe '#work method' do
    it 'completes the operation within 30 seconds' do
      expect { work(file_name: "data_large.txt", progress_bar: false) }.to perform_under(30).sec
    end
  end
end
