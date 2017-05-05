require 'spec_helper'

describe Aeternitas::Guard do
  describe '#with_lock' do
    let(:lock) { Aeternitas::Guard.new('MyId', 5.seconds, 10.minutes) }
    context 'when the lock is available' do
      before(:each) do
        @change_me = false
        lock.with_lock { @change_me = true }
      end

      it 'runs the block' do
        expect(@change_me).to be true
      end

      it 'sets lock key state to \'cooldown\'' do
        expect(JSON.parse(Aeternitas.redis.get('MyId'))['state']).to eq('cooldown')
      end

      it 'sets lock key timeout to 5 seconds' do
        expect(Time.parse(JSON.parse(Aeternitas.redis.get('MyId'))['locked_until'])).
          to be_between(4.seconds.from_now, 5.seconds.from_now)
      end

      it 'sets the locks cooldown time to 5 seconds' do
        expect(JSON.parse(Aeternitas.redis.get('MyId'))['cooldown'].to_i).to be(5.seconds.to_i)
      end

      it 'sets the locks timeout value 10 minutes' do
        expect(JSON.parse(Aeternitas.redis.get('MyId'))['timeout'].to_i).to be(10.minutes.to_i)
      end

      it 'set the key ttl to 5 seconds' do
        expect(Aeternitas.redis.ttl('MyId')).to be_between(4, 5)
      end
    end

    context 'when the lock is held by another process' do
      around(:each) do |example|
        Aeternitas::Guard.new(lock.id, lock.cooldown, lock.timeout).with_lock { example.run }
      end

      it 'does not run the block' do
        change_me = false
        begin
          lock.with_lock do
            change_me = true
          end
        rescue ; end
        expect(change_me).to be false
      end

      it 'raises a lock error' do
        expect{ lock.with_lock }.to raise_exception(Aeternitas::Guard::GuardIsLocked) do |e|
          expect(e.timeout).to be_between(4.seconds.from_now, 5.seconds.from_now)
        end
      end

      it 'does not change the lock' do
        expect(JSON.parse(Aeternitas.redis.get(lock.id))['token']).not_to be(lock.token)
      end
    end

    context 'when the lock is in cooldown' do
      before(:each) do
        Aeternitas::Guard.new(lock.id, lock.cooldown, lock.timeout).with_lock {}
      end

      it 'does not run the block' do
        change_me = false
        begin
          lock.with_lock do
            change_me = true
          end
        rescue ; end
        expect(change_me).to be false
      end

      it 'raises a lock error' do
        expect { lock.with_lock }.to raise_exception(Aeternitas::Guard::GuardIsLocked) do |e|
          expect(e.timeout).to be_between(4.seconds.from_now, 5.seconds.from_now)
        end
      end

      it 'does not change the lock' do
        expect(JSON.parse(Aeternitas.redis.get(lock.id))['token']).not_to be(lock.token)
      end
    end

    context 'when the lock is sleeping' do
      let(:sleep_timeout) { 20.minutes.from_now }
      before(:each) do
        Aeternitas::Guard.new(lock.id, lock.cooldown, lock.timeout)
          .sleep_until(sleep_timeout)
      end

      it 'does not run the block' do
        change_me = false
        begin
          lock.with_lock do
            change_me = true
          end
        rescue ; end
        expect(change_me).to be false
      end

      it 'raises a lock error' do
        expect{ lock.with_lock }.to raise_exception(Aeternitas::Guard::GuardIsLocked) do |e|
          expect(e.timeout).to be_within(1.second).of(sleep_timeout)
        end
      end

      it 'does not change the lock' do
        expect(JSON.parse(Aeternitas.redis.get(lock.id))['token']).not_to be(lock.token)
      end
    end
  end

  describe '#sleep_until' do
    before(:each) do
      Aeternitas::Guard.new('MyId', 5.seconds, 10.minutes)
        .sleep_until(5.hours.from_now)
    end

    it 'sets lock key state to \'sleeping\'' do
      expect(JSON.parse(Aeternitas.redis.get('MyId'))['state']).to eq('sleeping')
    end

    it 'sets lock key timeout to 5 hours' do
      expect(Time.parse(JSON.parse(Aeternitas.redis.get('MyId'))['locked_until'])).
        to be_within(1.second).of(5.hour.from_now)
    end

    it 'sets the locks cooldown time to 5 seconds' do
      expect(JSON.parse(Aeternitas.redis.get('MyId'))['cooldown'].to_i).to be(5.seconds.to_i)
    end

    it 'sets the locks timeout value 10 minutes' do
      expect(JSON.parse(Aeternitas.redis.get('MyId'))['timeout'].to_i).to be(10.minutes.to_i)
    end

    it 'set the key ttl to 5 hours' do
      expect(Aeternitas.redis.ttl('MyId')).to be_within(2.seconds).of(5.hours.to_i)
    end
  end
end