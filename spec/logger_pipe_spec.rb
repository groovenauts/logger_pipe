require 'spec_helper'

require 'stringio'
require 'logger'
require 'rbconfig'
require 'timeout'

describe LoggerPipe do
  it 'should have a version number' do
    LoggerPipe::VERSION.should_not be_nil
  end

  let(:buffer){ StringIO.new }
  let(:logger){ Logger.new(buffer) }

  describe ".run" do
    before{ buffer.truncate(0) }

    context "success" do
      let(:cmd){ "date +'Foo: %Y-%m-%dT%H:%M:%S'; sleep 1; date +'Bar: %Y-%m-%dT%H:%M:%S'" }
      it "returns STDOUT" do
        res = LoggerPipe.run(logger, cmd)
        res.should_not == ""
        res.lines.length.should == 2
        res.lines[0].should =~ /Foo: /
        res.lines[1].should =~ /Bar: /
      end

      it "logging output" do
        LoggerPipe.run(logger, cmd)
        msg = buffer.string
        msg.lines.length.should == 4
        msg.lines[0].should =~ /executing: #{Regexp.escape(cmd)}/
        msg.lines[1].should =~ /Foo: /
        msg.lines[2].should =~ /Bar: /
        msg.lines[3].should =~ /SUCCESS: #{Regexp.escape(cmd)}/
      end
    end

    context "failure" do
      let(:cmd){ "date +'Foo: %Y-%m-%dT%H:%M:%S'; #{RbConfig.ruby} -e 'exit(1)'" }

      it "raises Error" do
        expect{ LoggerPipe.run(logger, cmd) }.to raise_error(LoggerPipe::Failure)
      end

      it "failure" do
        LoggerPipe.run(logger, cmd) rescue nil
        msg = buffer.string
        msg.lines.length.should == 3
        msg.lines[0].should =~ /executing: #{Regexp.escape(cmd)}/
        msg.lines[1].should =~ /Foo: /
        msg.lines[2].should =~ /FAILURE: date \+'Foo: /
      end
    end


    context "timeout" do
      let(:cmd){ "date +'Foo: %Y-%m-%dT%H:%M:%S'; sleep 10; date +'Bar: %Y-%m-%dT%H:%M:%S'" }

      it "raises Error" do
        expect{ LoggerPipe.run(logger, cmd, timeout: 3) }.to raise_error(Timeout::Error)
      end

      it "failure" do
        LoggerPipe.run(logger, cmd, timeout: 3) rescue nil
        msg = buffer.string
        msg.lines[0].should =~ /executing: #{Regexp.escape(cmd)}/
        msg.lines[1].should =~ /Foo: /
        msg.lines[2].should =~ /now killing process/
        msg.lines.any?{|line| line =~ /EXECUTION Timeout/}.should == true
      end
    end

  end

end
