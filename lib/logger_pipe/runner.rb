# -*- coding: utf-8 -*-
require "logger_pipe"

require "timeout"

module LoggerPipe

  class Failure < StandardError
    attr_reader :buffer
    def initialize(msg, buffer)
      super(msg)
      @buffer = buffer
    end
  end

  class Runner
    attr_accessor :logger, :cmd, :timeout

    def initialize(logger, cmd, options = {})
      @logger, @cmd = logger, cmd
      @timeout = options[:timeout]
    end

    def execute
      logger.info("executing: #{cmd}")
      buf = []
      # systemをタイムアウトさせることはできないので、popenの戻り値を使っています。
      # see http://docs.ruby-lang.org/ja/2.0.0/class/Timeout.html
      com, pid = nil, nil
      begin
        Timeout.timeout( @timeout ) do

          # popenにブロックを渡さないと$?がnilになってしまうので敢えてブロックで処理しています。
          com = IO.popen(cmd) do |com|
            pid = com.pid
            while line = com.gets
              buf << line
              logger.info(line.chomp)
            end
          end
          if $?.exitstatus == 0
            logger.info("\e[32mSUCCESS: %s\e[0m" % [cmd])
            return buf.join
          else
            msg = "\e[31mFAILURE: %s\e[0m" % [cmd]
            logger.error(msg)
            raise Failure.new(msg, buf)
          end

        end
      rescue Timeout::Error => e
        logger.error("[#{e.class.name} #{e.message}] now killing process #{pid}: #{cmd}")
        begin
          Process.kill('SIGINT', pid) if pid
        rescue Exception => err
          logger.error("[#{err.class.name}] #{err.message}")
        end
        begin
          Timeout.timeout(10) do
            result = com.read
          end
        rescue Exception => err
          logger.error("failure to get result [#{err.class.name}] #{err.message}")
          result = "<failure to get result>"
        end
        begin
          msg = "\e[31mEXECUTION Timeout: %s\e[0m\n%s\n[result]: %s" % [cmd, buf.join.strip, result]
          logger.error(msg)
        rescue Exception => err
          logger.error("[#{err.class.name}] #{err.message}")
        end
        raise e
      end
    end

  end

end
