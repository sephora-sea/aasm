require 'spec_helper'

describe 'transitions' do

  it 'should raise an exception when whiny' do
    process = ProcessWithNewDsl.new
    expect { process.stop! }.to raise_error do |err|
      expect(err.class).to eql(AASM::InvalidTransition)
      expect(err.message).to eql("Event 'stop' cannot transition from 'sleeping'")
      expect(err.object).to eql(process)
      expect(err.event_name).to eql(:stop)
    end
    expect(process).to be_sleeping
  end

  it 'should not raise an exception when not whiny' do
    silencer = Silencer.new
    expect(silencer.smile!).to be_falsey
    expect(silencer).to be_silent
  end

  it 'should not raise an exception when superclass not whiny' do
    sub = SubClassing.new
    expect(sub.smile!).to be_falsey
    expect(sub).to be_silent
  end

  it 'should not raise an exception when from is nil even if whiny' do
    silencer = Silencer.new
    expect(silencer.smile_any!).to be_truthy
    expect(silencer).to be_smiling
  end

  it 'should call the block when success' do
    silencer = Silencer.new
    success = false
    expect {
      silencer.smile_any! do
        success = true
      end
    }.to change { success }.to(true)
  end

  it 'should not call the block when failure' do
    silencer = Silencer.new
    success = false
    expect {
      silencer.smile! do
        success = true
      end
    }.not_to change { success }
  end

end

describe 'blocks' do
end

describe AASM::Core::Transition do
  it 'should set from, to, and opts attr readers' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Core::Transition.new(opts)

    expect(st.from).to eq(opts[:from])
    expect(st.to).to eq(opts[:to])
    expect(st.opts).to eq(opts)
  end

  it 'should set on_transition with deprecation warning' do
    opts = {:from => 'foo', :to => 'bar'}
    st = AASM::Core::Transition.allocate
    expect(st).to receive(:warn).with('[DEPRECATION] :on_transition is deprecated, use :after instead')

    st.send :initialize, opts do
      guard :gg
      on_transition :after_callback
    end

    expect(st.opts[:after]).to eql [:after_callback]
  end

  it 'should set after, guard and success from dsl' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Core::Transition.new(opts) do
      guard :gg
      after :after_callback
      success :after_persist
    end

    expect(st.opts[:guard]).to eql ['g', :gg]
    expect(st.opts[:after]).to eql [:after_callback] # TODO fix this bad code coupling
    expect(st.opts[:success]).to eql [:after_persist] # TODO fix this bad code coupling
  end

  it 'should pass equality check if from and to are the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    allow(obj).to receive(:from).and_return(opts[:from])
    allow(obj).to receive(:to).and_return(opts[:to])

    expect(st).to eq(obj)
  end

  it 'should fail equality check if from are not the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    allow(obj).to receive(:from).and_return('blah')
    allow(obj).to receive(:to).and_return(opts[:to])

    expect(st).not_to eq(obj)
  end

  it 'should fail equality check if to are not the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    allow(obj).to receive(:from).and_return(opts[:from])
    allow(obj).to receive(:to).and_return('blah')

    expect(st).not_to eq(obj)
  end
end

describe AASM::Core::Transition, '- when performing guard checks' do
  it 'should return true of there is no guard' do
    opts = {:from => 'foo', :to => 'bar'}
    st = AASM::Core::Transition.new(opts)

    expect(st.allowed?(nil)).to be_truthy
  end

  it 'should call the method on the object if guard is a symbol' do
    opts = {:from => 'foo', :to => 'bar', :guard => :test}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    expect(st.allowed?(obj)).to be false
  end

  it 'should call the method on the object if unless is a symbol' do
    opts = {:from => 'foo', :to => 'bar', :unless => :test}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    expect(st.allowed?(obj)).to be true
  end

  it 'should call the method on the object if guard is a string' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'test'}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    expect(st.allowed?(obj)).to be false
  end

  it 'should call the method on the object if unless is a string' do
    opts = {:from => 'foo', :to => 'bar', :unless => 'test'}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    expect(st.allowed?(obj)).to be true
  end

  it 'should call the proc passing the object if the guard is a proc' do
    opts = {:from => 'foo', :to => 'bar', :guard => Proc.new { test }}
    st = AASM::Core::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    expect(st.allowed?(obj)).to be false
  end
end

describe AASM::Core::Transition, '- when executing the transition with a Proc' do
  it 'should call a Proc on the object with args' do
    opts = {:from => 'foo', :to => 'bar', :after => Proc.new {|a| test(a) }}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    expect(obj).to receive(:test).with(args)

    st.execute(obj, args)
  end

  it 'should call a Proc on the object without args' do
    # in order to test that the Proc has been called, we make sure
    # that after running the :after callback the prc_object is set
    prc_object = nil
    prc = Proc.new { prc_object = self }

    opts = {:from => 'foo', :to => 'bar', :after => prc }
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    st.execute(obj, args)
    expect(prc_object).to eql obj
  end
end

describe AASM::Core::Transition, '- when executing the transition with an :after method call' do
  it 'should accept a String for the method name' do
    opts = {:from => 'foo', :to => 'bar', :after => 'test'}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    expect(obj).to receive(:test)

    st.execute(obj, args)
  end

  it 'should accept a Symbol for the method name' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    expect(obj).to receive(:test)

    st.execute(obj, args)
  end

  it 'should pass args if the target method accepts them' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    def obj.test(args)
      "arg1: #{args[:arg1]} arg2: #{args[:arg2]}"
    end

    return_value = st.execute(obj, args)

    expect(return_value).to eq('arg1: 1 arg2: 2')
  end

  it 'should NOT pass args if the target method does NOT accept them' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    def obj.test
      'success'
    end

    return_value = st.execute(obj, args)

    expect(return_value).to eq('success')
  end

  it 'should allow accessing the from_state and the to_state' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    transition = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => AASM::InstanceBase.new('object'))

    def obj.test(args)
      "from: #{aasm.from_state} to: #{aasm.to_state}"
    end

    return_value = transition.execute(obj, args)

    expect(return_value).to eq('from: foo to: bar')
  end

end

describe AASM::Core::Transition, '- when invoking the transition :success method call' do
  it 'should accept a String for the method name' do
    opts = {:from => 'foo', :to => 'bar', :success => 'test'}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    expect(obj).to receive(:test)

    st.invoke_success_callbacks(obj, args)
  end

  it 'should accept a Symbol for the method name' do
    opts = {:from => 'foo', :to => 'bar', :success => :test}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    expect(obj).to receive(:test)

    st.invoke_success_callbacks(obj, args)
  end

  it 'should pass args if the target method accepts them' do
    opts = {:from => 'foo', :to => 'bar', :success => :test}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    def obj.test(args)
      "arg1: #{args[:arg1]} arg2: #{args[:arg2]}"
    end

    return_value = st.invoke_success_callbacks(obj, args)

    expect(return_value).to eq('arg1: 1 arg2: 2')
  end

  it 'should NOT pass args if the target method does NOT accept them' do
    opts = {:from => 'foo', :to => 'bar', :success => :test}
    st = AASM::Core::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    def obj.test
      'success'
    end

    return_value = st.invoke_success_callbacks(obj, args)

    expect(return_value).to eq('success')
  end

end
