# -*- coding: utf-8 -*-
require 'spec_helper'

require 'stringio'
require 'logger'
require 'rbconfig'
require 'timeout'

describe LoggerPipe do
  it 'should have a version number' do
    expect(LoggerPipe::VERSION).to_not be_nil
  end

  let(:buffer){ StringIO.new }
  let(:logger){ Logger.new(buffer) }

  describe ".run" do
    before{ buffer.truncate(0) }

    context "success" do
      let(:cmd){ "date +'Foo: %Y-%m-%dT%H:%M:%S'; sleep 1; date +'Bar: %Y-%m-%dT%H:%M:%S'" }
      it "returns STDOUT" do
        res = LoggerPipe.run(logger, cmd)
        expect(res).to_not eq ""
        expect(res.lines.length).to eq 2
        expect(res.lines[0]).to match /Foo: /
        expect(res.lines[1]).to match /Bar: /
      end

      it "logging output" do
        LoggerPipe.run(logger, cmd)
        msg = buffer.string
        expect(msg.lines.length).to eq 4
        expect(msg.lines[0]).to match /executing: #{Regexp.escape(cmd)}/
        expect(msg.lines[1]).to match /Foo: /
        expect(msg.lines[2]).to match /Bar: /
        expect(msg.lines[3]).to match /SUCCESS: #{Regexp.escape(cmd)}/
      end
    end

    context "stderr" do
      let(:cmd){ File.expand_path("../stderr_test.sh", __FILE__) }
      it "returns STDOUT on success" do
        res = LoggerPipe.run(logger, "#{cmd} 0")
        # puts buffer.string
        expect(buffer.string).to match /bar\n/
        expect(res).to eq "foo\nbaz\n"
      end

      it "buffer include stderr content on error" do
        expect{
          LoggerPipe.run(logger, "#{cmd} 1")
        }.to raise_error(LoggerPipe::Failure)
        # puts buffer.string
        expect(buffer.string).to match /bar\n/
      end
    end

    context "dry_run: true" do
      let(:cmd){ "date +'Foo: %Y-%m-%dT%H:%M:%S'; sleep 1; date +'Bar: %Y-%m-%dT%H:%M:%S'" }
      it "returns nil" do
        res = LoggerPipe.run(logger, cmd, dry_run: true)
        expect(res).to eq nil
      end

      it "logging output" do
        LoggerPipe.run(logger, cmd, dry_run: true)
        msg = buffer.string
        expect(msg.lines.length).to eq 1
        expect(msg.lines[0]).to match /dry run: #{Regexp.escape(cmd)}/
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
        expect(msg.lines.length).to eq 3
        expect(msg.lines[0]).to match /executing: #{Regexp.escape(cmd)}/
        expect(msg.lines[1]).to match /Foo: /
        expect(msg.lines[2]).to match /FAILURE: date \+'Foo: /
      end

      it "returns buffer from LoggerPipe::Failure" do
        begin
          LoggerPipe.run(logger, cmd)
          fail
        rescue LoggerPipe::Failure => e
          expect(e.buffer).to be_a(Array)
          expect(e.buffer.first).to match(/\AFoo: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        end
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
        expect(msg.lines[0]).to match /executing: #{Regexp.escape(cmd)}/
        expect(msg.lines[1]).to match /Foo: /
        expect(msg.lines[2]).to match /now killing process/
        expect(msg.lines.any?{|line| line =~ /EXECUTION Timeout/}).to eq true
      end
    end

  end

end
