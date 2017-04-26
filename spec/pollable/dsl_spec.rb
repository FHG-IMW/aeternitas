require 'spec_helper'

describe Aeternitas::Pollable::Dsl do
  let(:config) { Aeternitas::Pollable::Configuration.new }
  let(:dsl) { Aeternitas::Pollable::Dsl.new(config) {} }

  describe '#polling_frequency' do
    context 'when given a symbol' do
      it 'configures the matching Aeternitas:PollingFrequency' do
        dsl.polling_frequency :weekly
        expect(config.polling_frequency).to be Aeternitas::PollingFrequency::WEEKLY
      end

      it 'raises an error if the given preset is not present' do
        expect {dsl.polling_frequency :foo}.to raise_error(ArgumentError, 'Unknown polling frequency: foo')
      end
    end

    context 'when given a block' do
      it 'configures the lambda' do
        my_lambda = ->(pollable) { Time.now }
        dsl.polling_frequency my_lambda
        expect(config.polling_frequency).to be my_lambda
      end
    end
  end

  describe '#before_polling' do
    context 'when given a symbol' do
      it 'configures a method that tries to call the method on the given pollable' do
        pollable = spy('pollable')
        dsl.before_polling :my_method
        config.before_polling.first.call(pollable)
        expect(pollable).to have_received(:my_method)
      end
    end

    context 'when given a lambda' do
      it 'configures the lambda' do
        my_lambda = ->(pollable) { Time.now }
        dsl.before_polling my_lambda
        expect(config.before_polling).to include(my_lambda)
      end
    end
  end

  describe '#after_polling' do
    context 'when given a symbol' do
      it 'configures a method that tries to call the method on the given pollable' do
        pollable = spy('pollable')
        dsl.after_polling :my_method
        config.after_polling.first.call(pollable)
        expect(pollable).to have_received(:my_method)
      end
    end

    context 'when given a lambda' do
      it 'configures the lambda' do
        my_lambda = ->(pollable) { Time.now }
        dsl.after_polling my_lambda
        expect(config.after_polling).to include(my_lambda)
      end
    end
  end

  describe '#queue' do
    it 'configures the queue name' do
      dsl.queue "foobar"
      expect(config.queue).to eq "foobar"
    end
  end

  describe '#ignore_error' do
    it 'configures the specified errors as ignored_errors' do
      dsl.ignore_error(ArgumentError, IndexError)
      expect(config.ignored_errors).to include(ArgumentError, IndexError)
    end
  end

  describe '#deactivate_on' do
    it 'configures the specified errors as deactivation_errors' do
      dsl.deactivate_on(ArgumentError, IndexError)
      expect(config.deactivation_errors).to include(ArgumentError, IndexError)
    end
  end

  describe '#lock_key' do
    context 'when given a string' do
      it 'configures a method that returns that string' do
        dsl.lock_key 'Foo'
        expect(config.lock_options[:key].call(Object.new)).to eq 'Foo'
      end
    end

    context 'when given a symbol' do
      it 'configures a method that tries to call the method on the given pollable' do
        pollable = spy('pollable')
        dsl.lock_key :my_method
        config.lock_options[:key].call(pollable)
        expect(pollable).to have_received(:my_method)
      end
    end

    context 'when given a lambda' do
      it 'configures the lambda' do
        my_lambda = ->(pollable) { Time.now }
        dsl.lock_key my_lambda
        expect(config.lock_options[:key]).to be(my_lambda)
      end
    end
  end

  describe '#lock_options' do
    it 'configures the given options' do
      options = {
        key: 'Foo',
        cooldown: 1.second,
        timeout: 2.hours
      }
      dsl.lock_options options
      expect(config.lock_options).to eq(options)
    end
  end
end
